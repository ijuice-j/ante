import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// APPROACH 2: Fixed 7-col canvas with zoom checkpoints.
//
// The grid is ALWAYS 7 columns × 20 rows. Zooming is pure Transform.scale
// with viewport locking at checkpoints (7 / 6 / 5 / 4 / 3 / 2 visible cols).
// On release, scale & alignment snap to the nearest checkpoint so exactly N
// complete tiles fit the viewport. Non-focus rows fade out and back in
// during the snap. Virtual labels make rows read continuously.
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

class ZoomTestPage2 extends StatefulWidget {
  const ZoomTestPage2({super.key});

  @override
  State<ZoomTestPage2> createState() => _ZoomTestPage2State();
}

class _ZoomTestPage2State extends State<ZoomTestPage2>
    with SingleTickerProviderStateMixin {
  static const _cols = 7;
  static const _minVisible = 2;
  static const _maxVisible = 7;
  static const _totalItems = 140;
  static const _spacing = 2.0;

  // ---- transform state ----
  double _scale = 1.0;
  double _alignX = 0.0;
  double _alignY = 0.0;

  // ---- gesture tracking ----
  double _gestureBaseScale = 1.0;
  Offset _focalPoint = Offset.zero;

  // ---- snap animation ----
  late final AnimationController _snapCtl;
  double _snapFromScale = 1.0;
  double _snapToScale = 1.0;
  double _snapFromX = 0.0;
  double _snapToX = 0.0;
  double _snapFromY = 0.0;

  // ---- row fade during snap ----
  int _focusRow = 0;
  bool _isSnapping = false;
  double _fadeFactor = 0.0;

  // ---- virtual-grid labeling ----
  int _visibleN = 7;
  int _startCol = 0;
  int _pendingVisibleN = 7;
  int _pendingStartCol = 0;
  int _pendingFocusRow = 0;
  bool _pendingApplied = true;

  final ScrollController _scrollCtl = ScrollController();

  // ---- lifecycle ----

  @override
  void initState() {
    super.initState();
    _snapCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(_onSnapTick);
  }

  @override
  void dispose() {
    _snapCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  // ---- helpers ----

  double _scaleFor(int visible) => _cols / visible;

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

  int _labelFor(int row, int col) {
    if (_visibleN >= _cols) return row * _cols + col;
    final visibleCol = col - _startCol;
    if (visibleCol < 0 || visibleCol >= _visibleN) {
      return row * _cols + col;
    }
    if (row == _focusRow) return row * _cols + col;
    final focusBase = _focusRow * _cols + _startCol;
    return focusBase + (row - _focusRow) * _visibleN + visibleCol;
  }

  double _snapAlignX(int visible, double focalX, double vw) {
    if (visible >= _cols) return 0.0;
    final focalCol = (focalX * _cols / vw).clamp(0.0, _cols - 1.0);
    final c = (focalCol - visible / 2.0).round().clamp(0, _cols - visible);
    return 2.0 * c / (_cols - visible) - 1.0;
  }

  double _verticalPaddingFor(int visibleN) {
    final vh = context.size?.height ?? 0;
    return vh / 2 * (1 - visibleN / _cols);
  }

  // ---- gesture ----

  void _onScaleStart(ScaleStartDetails details) {
    _snapCtl.stop();
    _gestureBaseScale = _scale;
    _focalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalPoint = details.localFocalPoint;

    final raw = _gestureBaseScale * details.scale;
    final clamped = raw.clamp(_scaleFor(_maxVisible), _scaleFor(_minVisible));

    final size = context.size;
    if (size == null || size.width <= 0 || size.height <= 0) return;

    setState(() {
      _scale = clamped;
      _alignX = (_focalPoint.dx / size.width) * 2 - 1;
      _alignY = (_focalPoint.dy / size.height) * 2 - 1;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final targetVisible = _nearestCheckpoint(_scale);
    final targetScale = _scaleFor(targetVisible);
    final vw = context.size?.width ?? 0;
    final targetAlignX =
        vw > 0 ? _snapAlignX(targetVisible, _focalPoint.dx, vw) : 0.0;

    if (vw > 0 && _scrollCtl.hasClients) {
      final tileSize = (vw - _spacing * 2 - _spacing * (_cols - 1)) / _cols;
      final stride = tileSize + _spacing;
      final contentY = _scrollCtl.offset + _focalPoint.dy - _spacing;
      _focusRow = (contentY / stride).floor();
    }

    int targetStartCol = 0;
    if (targetVisible < _cols && vw > 0) {
      final focalCol =
          (_focalPoint.dx * _cols / vw).clamp(0.0, _cols - 1.0);
      targetStartCol = (focalCol - targetVisible / 2.0)
          .round()
          .clamp(0, _cols - targetVisible);
    }

    _pendingVisibleN = targetVisible;
    _pendingStartCol = targetStartCol;
    _pendingFocusRow = _focusRow;
    _pendingApplied = false;

    _snapFromScale = _scale;
    _snapToScale = targetScale;
    _snapFromX = _alignX;
    _snapToX = targetAlignX;
    _snapFromY = _alignY;
    _isSnapping = true;

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
        final oldPad = _verticalPaddingFor(_visibleN);
        final newPad = _verticalPaddingFor(_pendingVisibleN);
        final deltaPad = newPad - oldPad;

        _visibleN = _pendingVisibleN;
        _startCol = _pendingStartCol;
        _focusRow = _pendingFocusRow;
        _pendingApplied = true;

        if (deltaPad != 0 && _scrollCtl.hasClients) {
          final target = _scrollCtl.offset + deltaPad;
          _scrollCtl.jumpTo(math.max(0.0, target));
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
    final effective = (_cols / _scale).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Approach 2 · fixed 7-col canvas, checkpoint lock',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              'Visible ≈$effective  ×${_scale.toStringAsFixed(2)}  locked: $_visibleN',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        backgroundColor: Colors.black,
      ),
      body: RawGestureDetector(
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
                      padding: const EdgeInsets.all(_spacing),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _cols,
                          mainAxisSpacing: _spacing,
                          crossAxisSpacing: _spacing,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final row = index ~/ _cols;
                            final col = index % _cols;
                            final isFocusRow = row == _focusRow;
                            final opacity = (_isSnapping && !isFocusRow)
                                ? (1.0 - _fadeFactor * 0.85)
                                : 1.0;
                            final label = _labelFor(row, col);

                            return Opacity(
                              opacity: opacity,
                              child: _NumberTile(
                                  label: label, colorIndex: index),
                            );
                          },
                          childCount: _totalItems,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NumberTile extends StatelessWidget {
  final int label;
  final int colorIndex;
  const _NumberTile({required this.label, required this.colorIndex});

  @override
  Widget build(BuildContext context) {
    final hue = (colorIndex * 17) % 360;
    return Container(
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.3).toColor(),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '$label',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
