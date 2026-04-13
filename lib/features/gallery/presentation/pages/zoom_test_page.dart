import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Pinch recognizer that wins the gesture arena when 2+ fingers are down.
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
// ZoomTestPage
// ---------------------------------------------------------------------------
//
// Model:
//   • Base 7-col grid is ALWAYS mounted.
//   • Gestures always operate on the base grid — they scale it.
//   • Between gestures, when the user has zoomed in, an N-col overlay is
//     mounted on top of the base, covering it completely. This is a
//     "locked" state.
//   • As soon as a new gesture starts while the overlay is showing, the
//     overlay is disposed immediately. The base grid is snapped to a scale
//     that visually matches what the overlay was showing, and the user's
//     pinch continues naturally on the base.
// ---------------------------------------------------------------------------

class ZoomTestPage extends StatefulWidget {
  const ZoomTestPage({super.key});

  @override
  State<ZoomTestPage> createState() => _ZoomTestPageState();
}

class _ZoomTestPageState extends State<ZoomTestPage>
    with SingleTickerProviderStateMixin {
  static const _baseCols = 7;
  static const _minOverlayCols = 2;
  static const _totalItems = 140;
  static const _spacing = 2.0;
  static const _gridPad = 2.0;

  // ---- base transform ----
  double _baseScale = 1.0;
  Alignment _baseAlignment = Alignment.center;

  // ---- overlay ----
  bool _overlayVisible = false;
  double _overlayOpacity = 0.0;
  int _overlayCols = 4;
  Key _overlayKey = UniqueKey();

  // ---- gesture ----
  double _gestureStartScale = 1.0;
  Offset _focalPoint = Offset.zero;
  int _focusTileIndex = 0;

  // ---- animation ----
  late final AnimationController _animCtl;
  double _fromBaseScale = 1.0;
  double _toBaseScale = 1.0;
  Alignment _fromBaseAlignment = Alignment.center;
  Alignment _toBaseAlignment = Alignment.center;
  VoidCallback? _onAnimComplete;

  // ---- scroll ----
  final ScrollController _baseScrollCtl = ScrollController();
  final ScrollController _overlayScrollCtl = ScrollController();

  // ---- lifecycle ----

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )
      ..addListener(_onAnimTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          final cb = _onAnimComplete;
          _onAnimComplete = null;
          cb?.call();
        }
      });
  }

  @override
  void dispose() {
    _animCtl.dispose();
    _baseScrollCtl.dispose();
    _overlayScrollCtl.dispose();
    super.dispose();
  }

  // ---- tile math ----

  double _tileSize(int cols) {
    final vw = context.size?.width ?? 1;
    return (vw - _gridPad * 2 - _spacing * (cols - 1)) / cols;
  }

  double _rowStride(int cols) => _tileSize(cols) + _spacing;

  int _tileAtFocal({required bool inOverlay}) {
    final scrollCtl = inOverlay ? _overlayScrollCtl : _baseScrollCtl;
    if (!scrollCtl.hasClients) return 0;
    final cols = inOverlay ? _overlayCols : _baseCols;
    final stride = _rowStride(cols);
    final tile = _tileSize(cols);
    final xStride = tile + _spacing;

    final contentY = scrollCtl.offset + _focalPoint.dy - _gridPad;
    final contentX = _focalPoint.dx - _gridPad;

    final row = (contentY / stride).floor();
    final col = (contentX / xStride).floor().clamp(0, cols - 1);
    return (row * cols + col).clamp(0, _totalItems - 1);
  }

  double _scrollForFocus(int tileIndex, int cols) {
    final tile = _tileSize(cols);
    final stride = tile + _spacing;
    final row = tileIndex ~/ cols;
    // Place the MIDDLE of the focus row at focal_y. This avoids a
    // floating-point edge case where placing the top exactly at focal_y
    // can round-trip to row-1 in _tileAtFocal.
    final rowMid = row * stride + _gridPad + tile / 2;
    return math.max(0.0, rowMid - _focalPoint.dy);
  }

  // ---- gesture callbacks ----

  void _onScaleStart(ScaleStartDetails details) {
    _animCtl.stop();
    _onAnimComplete = null;
    _focalPoint = details.localFocalPoint;

    if (_overlayVisible) {
      // Capture the tile the user is focused on in the overlay.
      final focusTile = _tileAtFocal(inOverlay: true);
      _focusTileIndex = focusTile;

      // Jump the base scroll so the focus tile's row sits at focal_y.
      if (_baseScrollCtl.hasClients) {
        _baseScrollCtl.jumpTo(_scrollForFocus(focusTile, _baseCols));
      }

      // Set base scale to match the overlay's visual tile size.
      //   overlay tile = vw / N (at scale 1)
      //   base  tile  = vw / 7 × base_scale → base_scale = 7 / N
      _baseScale = _baseCols / _overlayCols.toDouble();

      // Anchor base scale transform at the pinch focal point.
      final size = context.size;
      if (size != null && size.width > 0 && size.height > 0) {
        _baseAlignment = Alignment(
          (_focalPoint.dx / size.width) * 2 - 1,
          (_focalPoint.dy / size.height) * 2 - 1,
        );
      }

      // Dispose the overlay immediately.
      _overlayVisible = false;
      _overlayOpacity = 0.0;
      setState(() {});
    } else {
      _focusTileIndex = _tileAtFocal(inOverlay: false);
    }

    _gestureStartScale = _baseScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _focalPoint = details.localFocalPoint;
    final size = context.size;
    if (size == null || size.width <= 0 || size.height <= 0) return;

    final raw = _gestureStartScale * details.scale;
    final clamped =
        raw.clamp(1.0, _baseCols / _minOverlayCols.toDouble());

    setState(() {
      _baseScale = clamped;
      _baseAlignment = Alignment(
        (_focalPoint.dx / size.width) * 2 - 1,
        (_focalPoint.dy / size.height) * 2 - 1,
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Recompute the focus tile using the CURRENT focal point. Fingers may
    // have drifted during the pinch. Because the base alignment tracks the
    // focal point (anchor = focal → child_y = focal_y regardless of scale),
    // the simple _tileAtFocal formula is valid here.
    _focusTileIndex = _tileAtFocal(inOverlay: false);

    final effective = _baseCols / _baseScale;
    final targetN =
        effective.round().clamp(_minOverlayCols, _baseCols);

    if (targetN >= _baseCols) {
      _animateBaseHome();
    } else {
      _enterOverlay(targetN);
    }
  }

  // ---- transitions ----

  /// Animate base back to its resting state (scale 1, alignment center).
  void _animateBaseHome() {
    _fromBaseScale = _baseScale;
    _toBaseScale = 1.0;
    _fromBaseAlignment = _baseAlignment;
    _toBaseAlignment = Alignment.center;
    _onAnimComplete = null;
    _animCtl.forward(from: 0);
  }

  /// Mount the overlay at the chosen N. The base animates to scale 7/N so
  /// the tile sizes match at the moment the overlay appears.
  void _enterOverlay(int targetN) {
    _overlayCols = targetN;
    _overlayKey = UniqueKey();

    _fromBaseScale = _baseScale;
    _toBaseScale = _baseCols / targetN.toDouble();
    _fromBaseAlignment = _baseAlignment;
    _toBaseAlignment = Alignment.center;
    _onAnimComplete = () {
      // Mount the overlay with opacity 0.
      setState(() {
        _overlayVisible = true;
        _overlayOpacity = 0.0;
      });
      // Next frame: the ScrollController is attached — jump scroll and
      // start the fade-in.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_overlayScrollCtl.hasClients) {
          _overlayScrollCtl
              .jumpTo(_scrollForFocus(_focusTileIndex, _overlayCols));
        }
        setState(() {
          _overlayOpacity = 1.0;
        });
      });
    };
    _animCtl.forward(from: 0);
  }

  void _onAnimTick() {
    final t = Curves.easeOutCubic.transform(_animCtl.value);
    setState(() {
      _baseScale = lerpDouble(_fromBaseScale, _toBaseScale, t)!;
      _baseAlignment =
          Alignment.lerp(_fromBaseAlignment, _toBaseAlignment, t)!;
    });
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Approach 1 · stacked N-col overlay',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              _overlayVisible
                  ? 'Overlay ${_overlayCols}col'
                  : 'Base 7col ×${_baseScale.toStringAsFixed(2)}',
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
        child: Stack(
          children: [
            // Base grid — always mounted.
            IgnorePointer(
              ignoring: _overlayVisible,
              child: ClipRect(
                child: Transform.scale(
                  scale: _baseScale,
                  alignment: _baseAlignment,
                  child: CustomScrollView(
                    controller: _baseScrollCtl,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(_gridPad),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _baseCols,
                            mainAxisSpacing: _spacing,
                            crossAxisSpacing: _spacing,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _NumberTile(
                              label: index,
                              colorIndex: index,
                            ),
                            childCount: _totalItems,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Overlay — mounted only while locked in the zoomed state.
            // Opaque background hides the base grid underneath, and fades
            // in when freshly attached.
            if (_overlayVisible)
              AnimatedOpacity(
                opacity: _overlayOpacity,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Container(
                  color: Colors.black,
                  child: CustomScrollView(
                    key: _overlayKey,
                    controller: _overlayScrollCtl,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(_gridPad),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _overlayCols,
                            mainAxisSpacing: _spacing,
                            crossAxisSpacing: _spacing,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _NumberTile(
                              label: index,
                              colorIndex: index,
                            ),
                            childCount: _totalItems,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
