import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A rotating asterisk used as a custom loading indicator.
///
/// - [width] and [height] are optional; they default to 40×40.
/// - [duration] controls how long one full rotation takes; default 1600ms.
/// - The spin is driven by a repeating [AnimationController] with an
///   easeInOutCubic curve so it feels organic rather than mechanical.
class AsteriskLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final Duration duration;

  const AsteriskLoader({
    super.key,
    this.width,
    this.height,
    this.duration = const Duration(milliseconds: 1600),
  });

  @override
  State<AsteriskLoader> createState() => _AsteriskLoaderState();
}

class _AsteriskLoaderState extends State<AsteriskLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AsteriskLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _ctl
        ..stop()
        ..duration = widget.duration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: CurvedAnimation(
        parent: _ctl,
        curve: Curves.easeInOutCubic,
      ),
      child: SvgPicture.asset(
        'assets/images/ic_asterisk.svg',
        width: widget.width ?? 40,
        height: widget.height ?? 40,
      ),
    );
  }
}
