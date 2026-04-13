import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/photo.dart';
import '../providers/gallery_providers.dart';
import 'photo_viewer_page.dart';

// ---------------------------------------------------------------------------
// APPROACH 4: masonry layout, aspect-ratio tiles, dynamic column count.
//
// Each of the 6 zoom levels (visibleN ∈ {2,3,4,5,6,7}) has its own
// pre-computed masonry layout — 140 photos flowing into N columns, packed
// into the shortest column by tile height. On release, we snap to the new
// level: Transform.scale animates from the gesture scale back to 1.0, and
// at the mid-point the grid rebuilds with the new column count and the
// scroll jumps to place the focus photo at the focal point.
// ---------------------------------------------------------------------------

class _PinchRecognizer extends ScaleGestureRecognizer {
  int _pointerCount = 0;

  _PinchRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointerCount++;
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointerCount = 0;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    if (_pointerCount >= 2) {
      acceptGesture(pointer);
    } else {
      super.rejectGesture(pointer);
    }
  }
}

// ---------------------------------------------------------------------------
// Precomputed position for one photo inside one zoom level's layout.
// ---------------------------------------------------------------------------

class _Tile {
  final int col;
  final double top;
  final double width;
  final double height;
  const _Tile({
    required this.col,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// All the tiles for a given visibleN packed into a masonry.
class _Layout {
  final int visibleN;
  final double colWidth;
  final double totalHeight;
  final List<_Tile> tiles; // indexed by photo index

  const _Layout({
    required this.visibleN,
    required this.colWidth,
    required this.totalHeight,
    required this.tiles,
  });
}

// ---------------------------------------------------------------------------

class ZoomTestPage4 extends ConsumerStatefulWidget {
  /// When true, the widget returns just the grid body — no Scaffold or
  /// AppBar — so it can be embedded inside another screen (e.g. Home).
  final bool embedded;

  const ZoomTestPage4({super.key, this.embedded = false});

  @override
  ConsumerState<ZoomTestPage4> createState() => _ZoomTestPage4State();
}

class _ZoomTestPage4State extends ConsumerState<ZoomTestPage4>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _minVisible = 2;
  static const _maxVisible = 7;
  static const _spacing = 2.0;
  static const _gridPad = 2.0;

  // Precomputed layouts, keyed by visibleN.
  final Map<int, _Layout> _layouts = {};
  List<Photo> _photos = const [];
  double _viewportWidth = 0;

  // ---- current state ----
  int _visibleN = 7;
  double _scale = 1.0;
  Alignment _alignment = Alignment.center;

  // ---- gesture ----
  double _gestureBaseScale = 1.0;
  Offset _focalPoint = Offset.zero;
  int _focusPhotoIndex = 0;

  // ---- snap animation ----
  late final AnimationController _snapCtl;
  double _fromScale = 1.0;
  double _toScale = 1.0;
  Alignment _fromAlignment = Alignment.center;
  int _pendingVisibleN = 7;
  double _pendingTargetScroll = 0.0;
  bool _pendingApplied = true;
  bool _isSnapping = false;
  double _fadeFactor = 0.0;

  final ScrollController _scrollCtl = ScrollController();

  // ---- lifecycle ----

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _snapCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(_onSnapTick);

    // Kick off permission request + initial photo load on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(permissionStatusProvider.notifier).requestPermission();
      if (!mounted) return;
      final status = ref.read(permissionStatusProvider);
      if (status == PermissionStatus.granted ||
          status == PermissionStatus.limited) {
        ref.read(photosProvider.notifier).loadInitial();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snapCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionStatusProvider.notifier).checkPermission();
    }
  }

  // ---- layout precomputation ----

  double _colWidthFor(int n) =>
      (_viewportWidth - _gridPad * 2 - _spacing * (n - 1)) / n;

  /// Build a masonry layout for [photos] at column count [n].
  _Layout _buildLayout(List<Photo> photos, int n) {
    final colWidth = _colWidthFor(n);
    final colHeights = List<double>.filled(n, 0.0);
    final tiles = <_Tile>[];

    for (final photo in photos) {
      // Find shortest column.
      int shortestCol = 0;
      double shortestH = colHeights[0];
      for (int c = 1; c < n; c++) {
        if (colHeights[c] < shortestH) {
          shortestCol = c;
          shortestH = colHeights[c];
        }
      }

      // Tile height preserves the photo's aspect ratio at the column width.
      // Fall back to a square if we don't have real dimensions.
      final double h;
      if (photo.width > 0 && photo.height > 0) {
        h = colWidth * photo.height / photo.width;
      } else {
        h = colWidth;
      }

      tiles.add(_Tile(
        col: shortestCol,
        top: colHeights[shortestCol],
        width: colWidth,
        height: h,
      ));
      colHeights[shortestCol] += h + _spacing;
    }

    final totalHeight = colHeights.reduce(math.max) + _gridPad * 2;
    return _Layout(
      visibleN: n,
      colWidth: colWidth,
      totalHeight: totalHeight,
      tiles: tiles,
    );
  }

  void _rebuildLayouts(List<Photo> photos, double viewportWidth) {
    if (identical(photos, _photos) && _viewportWidth == viewportWidth) {
      return;
    }
    _photos = photos;
    _viewportWidth = viewportWidth;
    _layouts.clear();
    for (int n = _minVisible; n <= _maxVisible; n++) {
      _layouts[n] = _buildLayout(photos, n);
    }
  }

  _Layout? get _layout => _layouts[_visibleN];

  // ---- focus helpers ----

  int _photoAtFocal() {
    final layout = _layout;
    if (layout == null || !_scrollCtl.hasClients) return 0;

    // Content-space Y at the focal point (gesture state alignment = focal
    // point, so child-y equals focal_y regardless of scale).
    final contentY = _scrollCtl.offset + _focalPoint.dy - _gridPad;
    final contentX = _focalPoint.dx - _gridPad;

    // Find the photo whose tile bounds contain (contentX, contentY).
    // Brute-force scan — fine for 140 items.
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < layout.tiles.length; i++) {
      final t = layout.tiles[i];
      final left =
          _gridPad + t.col * (layout.colWidth + _spacing) + layout.colWidth / 2;
      final mid = t.top + t.height / 2 + _gridPad;
      // Prefer an actual hit, but also track closest in case we're between.
      final dx = (contentX - (left - _gridPad)).abs();
      final dy = (contentY - (mid - _gridPad)).abs();
      final d = dx + dy;
      if (contentX >= left - _gridPad - layout.colWidth / 2 &&
          contentX <= left - _gridPad + layout.colWidth / 2 &&
          contentY >= t.top &&
          contentY <= t.top + t.height) {
        return i;
      }
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Scroll offset that places photo [photoIndex]'s middle at focal_y
  /// in the layout for [visibleN]. Assumes final state (scale = 1, alignY = 0).
  double _scrollForFocus(int photoIndex, int visibleN) {
    final layout = _layouts[visibleN];
    if (layout == null || photoIndex < 0 || photoIndex >= layout.tiles.length) {
      return 0;
    }
    final tile = layout.tiles[photoIndex];
    final midY = _gridPad + tile.top + tile.height / 2;
    final target = midY - _focalPoint.dy;
    return math.max(0.0, target);
  }

  /// Deterministic light-grey shade per tile index so the snap-time
  /// placeholders have subtle per-tile variation instead of all being
  /// the exact same color.
  static Color _placeholderGrey(int index) {
    const base = 0xDC;
    final offset = (index * 17) % 28;
    final value = base + offset; // 0xDC..0xF7
    return Color.fromARGB(0xFF, value, value, value);
  }

  int _nearestCheckpoint(double scale) {
    // Effective N = _visibleN / scale (pinch in → bigger scale → fewer cols).
    final effective = _visibleN / scale;
    int best = _maxVisible;
    double bestDist = (effective - best).abs();
    for (int n = _maxVisible; n >= _minVisible; n--) {
      final d = (effective - n).abs();
      if (d < bestDist) {
        bestDist = d;
        best = n;
      }
    }
    return best;
  }

  // ---- gesture callbacks ----

  void _onScaleStart(ScaleStartDetails details) {
    _snapCtl.stop();
    _gestureBaseScale = _scale;
    _focalPoint = details.localFocalPoint;
    _focusPhotoIndex = _photoAtFocal();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalPoint = details.localFocalPoint;
    final size = context.size;
    if (size == null || size.width <= 0 || size.height <= 0) return;

    final raw = _gestureBaseScale * details.scale;

    // Already at max zoom-out (7 cols visible) — block pinch-out entirely.
    if (_visibleN >= _maxVisible && raw <= 1.0) {
      return;
    }

    // Clamp so the effective col count stays within the checkpoint range.
    final minScale = _visibleN / _maxVisible.toDouble();
    final maxScale = _visibleN / _minVisible.toDouble();
    final clamped = raw.clamp(minScale, maxScale);

    setState(() {
      _scale = clamped;
      _alignment = Alignment(
        (_focalPoint.dx / size.width) * 2 - 1,
        (_focalPoint.dy / size.height) * 2 - 1,
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // If the user never actually changed anything (e.g. pinched-out at
    // 7-cols, which is blocked), skip the snap animation entirely.
    if (_visibleN >= _maxVisible && _scale <= 1.0 + 0.001) {
      return;
    }

    // Re-read the focus photo in case the fingers drifted.
    _focusPhotoIndex = _photoAtFocal();

    final targetN = _nearestCheckpoint(_scale);
    // Target "local" scale in the OLD layout such that tile widths match
    // the new layout's scale-1 tile width.
    //   (oldColW) * targetLocalScale = newColW
    //   targetLocalScale = newColW / oldColW
    final oldLayout = _layout;
    final newLayout = _layouts[targetN];
    final double targetScale;
    if (oldLayout != null && newLayout != null && oldLayout.colWidth > 0) {
      targetScale = newLayout.colWidth / oldLayout.colWidth;
    } else {
      targetScale = 1.0;
    }

    _pendingVisibleN = targetN;
    _pendingTargetScroll = _scrollForFocus(_focusPhotoIndex, targetN);
    _pendingApplied = false;

    _fromScale = _scale;
    _toScale = targetScale;
    _fromAlignment = _alignment;
    _isSnapping = true;

    _snapCtl.forward(from: 0);
  }

  void _onSnapTick() {
    final linearT = _snapCtl.value;
    final t = Curves.easeOutCubic.transform(linearT);
    final fade = math.sin(linearT * math.pi);

    setState(() {
      _fadeFactor = fade;

      if (!_pendingApplied) {
        // Phase 1: still on the OLD layout — animate scale/alignment.
        _scale = lerpDouble(_fromScale, _toScale, t)!;
        _alignment = Alignment(
          lerpDouble(_fromAlignment.x, 0.0, t)!,
          lerpDouble(_fromAlignment.y, 0.0, t)!,
        );

        if (linearT >= 0.5) {
          // Swap to NEW layout, reset to natural scale/alignment, jump
          // scroll to keep the focus photo at the focal point.
          _visibleN = _pendingVisibleN;
          _scale = 1.0;
          _alignment = Alignment.center;
          _pendingApplied = true;

          if (_scrollCtl.hasClients) {
            _scrollCtl.jumpTo(math.max(0.0, _pendingTargetScroll));
          }
        }
      }
      // Phase 2: grid already swapped, scale/alignment already at final
      // values — leave them alone so we don't overwrite with a stale lerp.

      if (_snapCtl.isCompleted) {
        _isSnapping = false;
        _fadeFactor = 0.0;
      }
    });
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(permissionStatusProvider);
    final photosAsync = ref.watch(photosProvider);

    ref.listen(permissionStatusProvider, (prev, next) {
      if (next == PermissionStatus.granted &&
          prev != PermissionStatus.granted) {
        ref.read(photosProvider.notifier).loadInitial();
      }
    });

    final body = _buildBody(permission, photosAsync);

    if (widget.embedded) {
      return ColoredBox(color: Colors.white, child: body);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Approach 4 · dynamic masonry',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            Text(
              _photos.isEmpty
                  ? 'Loading photos…'
                  : 'N=$_visibleN  photos=${_photos.length}  '
                      '×${_scale.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildBody(
    PermissionStatus permission,
    AsyncValue<List<Photo>> photosAsync,
  ) {
    switch (permission) {
      case PermissionStatus.unknown:
        return const Center(
          child: CircularProgressIndicator(color: Colors.black54),
        );
      case PermissionStatus.denied:
        return _buildPermissionDenied();
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        break;
    }

    return photosAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.black54),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load photos\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ),
      data: (photos) {
        if (photos.isEmpty) {
          return const Center(
            child: Text(
              'No photos found',
              style: TextStyle(color: Colors.black87),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            _rebuildLayouts(photos, constraints.maxWidth);
            return _buildGrid(photos);
          },
        );
      },
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 56, color: Colors.black54),
            const SizedBox(height: 16),
            const Text(
              'Photo access required',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Grant access to your photo library to see the masonry zoom '
              'test run on your actual photos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref
                  .read(permissionStatusProvider.notifier)
                  .requestPermission(),
              child: const Text('Allow access'),
            ),
            TextButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text(
                'Open settings',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Photo> photos) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _PinchRecognizer:
            GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
          () => _PinchRecognizer(debugOwner: this),
          (r) {
            r
              ..onStart = _onScaleStart
              ..onUpdate = _onScaleUpdate
              ..onEnd = _onScaleEnd;
          },
        ),
      },
      child: ClipRect(
        child: Transform.scale(
          scale: _scale,
          alignment: _alignment,
          child: CustomScrollView(
            controller: _scrollCtl,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(_gridPad),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: _visibleN,
                  mainAxisSpacing: _spacing,
                  crossAxisSpacing: _spacing,
                  childCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final aspect = (photo.width > 0 && photo.height > 0)
                        ? photo.width / photo.height
                        : 1.0;
                    final isFocus = index == _focusPhotoIndex;

                    // During the snap, replace non-focus tiles with a grey
                    // placeholder (random shade per tile) that fades out and
                    // back in, so the layout reshuffle is less visible.
                    if (_isSnapping && !isFocus) {
                      return AspectRatio(
                        aspectRatio: aspect,
                        child: Opacity(
                          opacity: 1.0 - _fadeFactor * 0.85,
                          child: ColoredBox(
                            color: _placeholderGrey(index),
                          ),
                        ),
                      );
                    }

                    return AspectRatio(
                      aspectRatio: aspect,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push(
                          '/viewer',
                          extra: PhotoViewerArgs(
                            photos: photos,
                            initialIndex: index,
                          ),
                        ),
                        child: _PhotoTile(photo: photo),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PhotoTile extends StatelessWidget {
  final Photo photo;
  const _PhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    final thumb = photo.thumbnail;
    return Container(
      color: const Color(0xFFEEEEEE),
      child: thumb == null
          ? null
          : Image.memory(
              thumb,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: 200,
            ),
    );
  }
}
