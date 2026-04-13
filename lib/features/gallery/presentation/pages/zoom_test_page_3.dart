import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/photo.dart';
import '../providers/gallery_providers.dart';
import 'photo_viewer_page.dart';

// ---------------------------------------------------------------------------
// APPROACH 3: single persistent 7-col canvas, variable content mapping.
//
// The SliverGrid always has crossAxisCount = 7. Its childCount grows with
// the zoom level: rowsUsed × 7, where rowsUsed = ⌈140 / N⌉. At each zoom
// level a function maps the slot (row, col) to an item — slots outside the
// "filled block" (a contiguous N-column strip of the 7-col canvas) render
// as SizedBox.shrink() so they take no visual space. Transform.scale zooms
// into the filled block; alignment is chosen so the filled N columns
// exactly fill the viewport at the checkpoint scale.
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

class ZoomTestPage3 extends ConsumerStatefulWidget {
  /// When true, the widget returns just the grid body — no Scaffold or
  /// AppBar — so it can be embedded inside another screen (e.g. Home).
  final bool embedded;

  const ZoomTestPage3({super.key, this.embedded = false});

  @override
  ConsumerState<ZoomTestPage3> createState() => _ZoomTestPage3State();
}

class _ZoomTestPage3State extends ConsumerState<ZoomTestPage3>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _cols = 7;
  static const _minVisible = 2;
  static const _maxVisible = 7;
  static const _spacing = 2.0;
  static const _gridPad = 2.0;

  // Lazily-resolved photo count (from the Riverpod state).
  int _totalItems = 0;

  // ---- current filled-block state ----
  int _visibleN = 7;
  int _startCol = 0;

  // ---- transform state ----
  double _scale = 1.0;
  double _alignX = 0.0;
  double _alignY = 0.0;

  // ---- gesture tracking ----
  double _gestureBaseScale = 1.0;
  Offset _focalPoint = Offset.zero;
  int _focusTileIndex = 0;

  // ---- snap animation ----
  late final AnimationController _snapCtl;
  double _snapFromScale = 1.0;
  double _snapToScale = 1.0;
  double _snapFromX = 0.0;
  double _snapToX = 0.0;
  double _snapFromY = 0.0;

  // Pending values applied at the midpoint.
  int _pendingVisibleN = 7;
  int _pendingStartCol = 0;
  int _pendingFocusRow = 0;
  double _pendingTargetScroll = 0.0;
  bool _pendingApplied = true;

  // Focus row used for the fade (kept stable during the gesture).
  int _focusRow = 0;
  bool _isSnapping = false;
  bool _isGesturing = false;
  double _fadeFactor = 0.0;

  // ---- scroll ----
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

    // Kick off permission request on the next frame. If permission is
    // already granted, also trigger the initial photo load — the
    // ref.listen below only fires on transitions, which won't happen if
    // the Launch screen already handled the grant.
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
    // Re-check the permission when returning from system settings.
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionStatusProvider.notifier).checkPermission();
    }
  }

  // ---- derived ----

  int get _rowsUsed => (_totalItems / _visibleN).ceil();
  int get _childCount => _rowsUsed * _cols;

  double _tileSize() {
    final vw = context.size?.width ?? 1;
    return (vw - _gridPad * 2 - _spacing * (_cols - 1)) / _cols;
  }

  /// Returns the item index at slot [index] for the CURRENT state,
  /// or null if the slot is an empty cell outside the filled block.
  int? _itemAtSlot(int index, {int? visibleN, int? startCol}) {
    final n = visibleN ?? _visibleN;
    final sc = startCol ?? _startCol;
    final row = index ~/ _cols;
    final col = index % _cols;
    if (col < sc || col >= sc + n) return null;
    final relCol = col - sc;
    final item = row * n + relCol;
    if (item >= _totalItems) return null;
    return item;
  }

  /// Item under the focal point in the current (pre-snap) state.
  int _tileAtFocal() {
    if (!_scrollCtl.hasClients) return 0;
    final tile = _tileSize();
    final stride = tile + _spacing;
    final xStride = tile + _spacing;

    final contentY = _scrollCtl.offset + _focalPoint.dy - _gridPad;
    final contentX = _focalPoint.dx - _gridPad;

    final slotRow = (contentY / stride).floor().clamp(0, _rowsUsed - 1);
    final slotCol =
        (contentX / xStride).floor().clamp(0, _cols - 1);

    // If the focal point is on a filled cell, return it directly.
    final slotIndex = slotRow * _cols + slotCol;
    final item = _itemAtSlot(slotIndex);
    if (item != null) return item;

    // Otherwise project onto the nearest filled col.
    final projectedCol =
        slotCol.clamp(_startCol, _startCol + _visibleN - 1);
    final relCol = projectedCol - _startCol;
    return (slotRow * _visibleN + relCol).clamp(0, _totalItems - 1);
  }

  /// Scroll offset that places [tileIndex]'s row at focal_y given the
  /// TARGET state (alignY = 0 center, scale = 7/visibleN, with matching
  /// top/bottom padding added as slivers around the grid).
  ///
  /// Derivation: at alignY = 0 and scale S, content at screen focal_y is
  ///   c = scroll + vh/2 + (focal_y − vh/2) / S
  /// With top padding of vh/2·(1−1/S), absoluteRowMid = padTop + rowMid,
  /// and solving c = absoluteRowMid collapses to:
  ///   scroll = rowMid − focal_y / S
  double _scrollForFocus(int tileIndex, int visibleN) {
    final tile = _tileSize();
    final stride = tile + _spacing;
    final row = tileIndex ~/ visibleN;
    final rowMid = row * stride + _gridPad + tile / 2;
    final targetScale = _cols / visibleN.toDouble();
    return math.max(0.0, rowMid - _focalPoint.dy / targetScale);
  }

  /// Compute startCol that centers the filled block on the focal column
  /// (derived from focal_x in the 7-col canvas).
  int _startColFor(int visibleN) {
    if (visibleN >= _cols) return 0;
    final vw = context.size?.width ?? 1;
    final focalCanvasCol =
        (_focalPoint.dx * _cols / vw).clamp(0.0, _cols - 1.0);
    return (focalCanvasCol - visibleN / 2.0)
        .round()
        .clamp(0, _cols - visibleN);
  }

  /// Alignment.x that places canvas cols [startCol .. startCol+visibleN)
  /// exactly in the viewport.
  double _snapAlignX(int visibleN, int startCol) {
    if (visibleN >= _cols) return 0.0;
    return 2.0 * startCol / (_cols - visibleN) - 1.0;
  }

  int _nearestCheckpoint(double scale) {
    final effective = _cols / scale;
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
    _isGesturing = true;
    _gestureBaseScale = _scale;
    _focalPoint = details.localFocalPoint;
    _focusTileIndex = _tileAtFocal();
    _focusRow = _focusTileIndex ~/ _visibleN;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalPoint = details.localFocalPoint;
    final raw = _gestureBaseScale * details.scale;

    // Already at max zoom-out (7 cols visible) — block pinch-out entirely.
    // Don't even update alignment, so the grid doesn't shift at all.
    if (_visibleN >= _maxVisible && raw <= 1.0) {
      return;
    }

    final clamped = raw.clamp(
      _cols / _maxVisible,
      _cols / _minVisible,
    );

    final size = context.size;
    if (size == null || size.width <= 0 || size.height <= 0) return;

    setState(() {
      _scale = clamped;
      _alignX = (_focalPoint.dx / size.width) * 2 - 1;
      _alignY = (_focalPoint.dy / size.height) * 2 - 1;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // If the user never actually changed anything (e.g. pinched-out at
    // 7-cols, which is blocked), skip the snap animation entirely.
    if (_visibleN >= _maxVisible && _scale <= 1.0 + 0.001) {
      _isGesturing = false;
      return;
    }

    // Recompute focus tile from the final focal point.
    _focusTileIndex = _tileAtFocal();

    final targetN = _nearestCheckpoint(_scale);
    final targetStartCol = _startColFor(targetN);
    final targetScale = _cols / targetN.toDouble();
    final targetAlignX = _snapAlignX(targetN, targetStartCol);
    final targetScroll = _scrollForFocus(_focusTileIndex, targetN);

    _pendingVisibleN = targetN;
    _pendingStartCol = targetStartCol;
    _pendingFocusRow = _focusTileIndex ~/ targetN;
    _pendingTargetScroll = targetScroll;
    _pendingApplied = false;

    _snapFromScale = _scale;
    _snapToScale = targetScale;
    _snapFromX = _alignX;
    _snapToX = targetAlignX;
    _snapFromY = _alignY;
    _isSnapping = true;
    _isGesturing = false;

    _snapCtl.forward(from: 0);
  }

  void _onSnapTick() {
    final linearT = _snapCtl.value;
    final t = Curves.easeOutCubic.transform(linearT);
    final fade = math.sin(linearT * math.pi);

    setState(() {
      _scale = lerpDouble(_snapFromScale, _snapToScale, t)!;
      _alignX = lerpDouble(_snapFromX, _snapToX, t)!;
      _alignY = lerpDouble(_snapFromY, 0.0, t)!;
      _fadeFactor = fade;

      if (!_pendingApplied && linearT >= 0.5) {
        _visibleN = _pendingVisibleN;
        _startCol = _pendingStartCol;
        _focusRow = _pendingFocusRow;
        _pendingApplied = true;

        if (_scrollCtl.hasClients) {
          // Don't clamp against the current maxScrollExtent — that's still
          // the OLD grid's max. The grid is about to rebuild with the new
          // _visibleN and its max will update in the same frame.
          _scrollCtl.jumpTo(math.max(0.0, _pendingTargetScroll));
        }
      }
    });

    if (_snapCtl.isCompleted) {
      _isSnapping = false;
      _fadeFactor = 0.0;
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final permissionStatus = ref.watch(permissionStatusProvider);
    final photosAsync = ref.watch(photosProvider);

    // When permission is granted, kick off the photo load once.
    ref.listen(permissionStatusProvider, (prev, next) {
      if (next == PermissionStatus.granted &&
          prev != PermissionStatus.granted) {
        ref.read(photosProvider.notifier).loadInitial();
      }
    });

    final body = _buildBody(permissionStatus, photosAsync);

    if (widget.embedded) {
      return ColoredBox(color: Colors.white, child: body);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        foregroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Approach 3 · 7-col canvas, variable fill',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            Text(
              _totalItems == 0
                  ? 'Loading photos…'
                  : 'N=$_visibleN  startCol=$_startCol  '
                      'rowsUsed=$_rowsUsed  photos=$_totalItems  '
                      '×${_scale.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
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
        // Sync photo count into state used by the math helpers.
        if (_totalItems != photos.length) {
          // Build happens synchronously; update after frame so state is
          // consistent for the grid structure.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _totalItems != photos.length) {
              setState(() => _totalItems = photos.length);
            }
          });
        }
        return _buildGrid(photos);
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
              'Grant access to your photo library to see the zoom test '
              'run on your actual photos.',
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vh = constraints.maxHeight;
          // Symmetric top + bottom padding that grows with zoom so the
          // scroll range reaches the very top and very bottom rows.
          final verticalPad = vh / 2 * (1 - _visibleN / _cols);

          return ClipRect(
            child: Transform.scale(
              scale: _scale,
              alignment: Alignment(_alignX, _alignY),
              child: CustomScrollView(
                controller: _scrollCtl,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: verticalPad),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(_gridPad),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _cols,
                        mainAxisSpacing: _spacing,
                        crossAxisSpacing: _spacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _itemAtSlot(index);
                          if (item == null || item >= photos.length) {
                            // Only paint a grey placeholder while a gesture
                            // or snap is in progress — at rest the cell
                            // stays transparent so trailing-empty slots
                            // aren't visible.
                            if (_isGesturing || _isSnapping) {
                              return const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFE8E8E8),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                          final row = index ~/ _cols;
                          final isFocusRow = row == _focusRow;
                          final opacity = (_isSnapping && !isFocusRow)
                              ? (1.0 - _fadeFactor * 0.85)
                              : 1.0;
                          return Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.push(
                                '/viewer',
                                extra: PhotoViewerArgs(
                                  photos: photos,
                                  initialIndex: item,
                                ),
                              ),
                              child: _PhotoTile(photo: photos[item]),
                            ),
                          );
                        },
                        childCount: _childCount,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: verticalPad),
                  ),
                ],
              ),
            ),
          );
        },
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
