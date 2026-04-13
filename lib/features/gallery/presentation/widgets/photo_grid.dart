import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/photo.dart';

// ---------------------------------------------------------------------------
// Gesture recognizer that wins over the scroll view when 2+ fingers are down.
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
// PhotoGrid
// ---------------------------------------------------------------------------

class PhotoGrid extends StatefulWidget {
  final List<Photo> photos;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const PhotoGrid({
    super.key,
    required this.photos,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  static const _minColumns = 3;
  static const _maxColumns = 7;
  static const _gridSpacing = 2.0;
  static const _gridPadding = 2.0;

  int _columnCount = 7;
  double _visualScale = 1.0;
  Alignment _scaleAlignment = Alignment.center;

  int _gestureStartColumns = 7;
  Offset _focalPoint = Offset.zero;
  int _focusPhotoIndex = 0;

  final ScrollController _scrollController = ScrollController();

  // ----------------------- helpers -----------------------

  double _tileSize(double vw, int cols) =>
      (vw - _gridPadding * 2 - _gridSpacing * (cols - 1)) / cols;

  double _rowStride(double vw, int cols) =>
      _tileSize(vw, cols) + _gridSpacing;

  int _photoIndexAt(Offset point) {
    if (!_scrollController.hasClients) return 0;
    final vw = context.size?.width ?? 1;
    final tile = _tileSize(vw, _columnCount);
    final stride = tile + _gridSpacing;

    final contentY = _scrollController.offset + point.dy - _gridPadding;
    final contentX = point.dx - _gridPadding;

    final row = (contentY / stride).floor();
    final col =
        (contentX / (tile + _gridSpacing)).floor().clamp(0, _columnCount - 1);
    return (row * _columnCount + col).clamp(0, widget.photos.length - 1);
  }

  // ----------------------- gesture -----------------------

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartColumns = _columnCount;
    _focalPoint = details.localFocalPoint;
    _focusPhotoIndex = _photoIndexAt(_focalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalPoint = details.localFocalPoint;

    final clampedScale = details.scale.clamp(
      _gestureStartColumns / _maxColumns.toDouble(),
      _gestureStartColumns / _minColumns.toDouble(),
    );

    final size = context.size;
    if (size != null && size.width > 0 && size.height > 0) {
      _scaleAlignment = Alignment(
        (_focalPoint.dx / size.width) * 2 - 1,
        (_focalPoint.dy / size.height) * 2 - 1,
      );
    }

    setState(() => _visualScale = clampedScale);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final effectiveCols = (_gestureStartColumns / _visualScale)
        .clamp(_minColumns.toDouble(), _maxColumns.toDouble());
    final targetCols = effectiveCols.round().clamp(_minColumns, _maxColumns);
    final oldCols = _columnCount;
    final vw = context.size?.width ?? 0;

    setState(() {
      _columnCount = targetCols;
      _visualScale = 1.0;
    });

    if (oldCols != targetCols && vw > 0) {
      _adjustScrollForFocus(oldCols, targetCols, vw);
    }
  }

  void _adjustScrollForFocus(int oldCols, int newCols, double vw) {
    if (!_scrollController.hasClients) return;

    final oldStride = _rowStride(vw, oldCols);
    final newStride = _rowStride(vw, newCols);

    final oldContentY =
        (_focusPhotoIndex ~/ oldCols) * oldStride + _gridPadding;
    final screenY = oldContentY - _scrollController.offset;

    final newContentY =
        (_focusPhotoIndex ~/ newCols) * newStride + _gridPadding;

    _scrollController.jumpTo(math.max(0.0, newContentY - screenY));
  }

  // ----------------------- build -----------------------

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _PinchRecognizer:
            GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
          () => _PinchRecognizer(debugOwner: this),
          (recognizer) {
            recognizer
              ..onStart = _onScaleStart
              ..onUpdate = _onScaleUpdate
              ..onEnd = _onScaleEnd;
          },
        ),
      },
      child: ClipRect(
        child: Transform.scale(
          scale: _visualScale,
          alignment: _scaleAlignment,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 300) {
                widget.onLoadMore();
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(_gridPadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columnCount,
                      mainAxisSpacing: _gridSpacing,
                      crossAxisSpacing: _gridSpacing,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _PhotoTile(photo: widget.photos[index]),
                      childCount: widget.photos.length,
                    ),
                  ),
                ),
                if (widget.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo tile
// ---------------------------------------------------------------------------

class _PhotoTile extends StatelessWidget {
  final Photo photo;

  const _PhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photo.thumbnail != null)
          Image.memory(
            photo.thumbnail!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 200,
          )
        else
          Container(color: AppTheme.cardDark),
        if (photo.isVideo)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    _formatDuration(photo.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

// ---------------------------------------------------------------------------
// Shimmer placeholder
// ---------------------------------------------------------------------------

class PhotoShimmerGrid extends StatefulWidget {
  const PhotoShimmerGrid({super.key});

  @override
  State<PhotoShimmerGrid> createState() => _PhotoShimmerGridState();
}

class _PhotoShimmerGridState extends State<PhotoShimmerGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 42,
          itemBuilder: (context, index) => Container(
            color: AppTheme.cardDark.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}
