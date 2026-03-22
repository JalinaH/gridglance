import 'package:flutter/material.dart';

/// Wraps any tappable widget with a scale-bounce micro-interaction.
///
/// Uses [Listener] so it does NOT consume pointer events — the child's own
/// gesture handlers (e.g. `onPressed`, `onChanged`) continue to work normally.
/// This widget only adds the visual scale effect.
class BounceTap extends StatefulWidget {
  final Widget child;
  final double scaleDown;
  final Duration duration;

  const BounceTap({
    super.key,
    required this.child,
    this.scaleDown = 0.93,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: Duration(
        milliseconds: (widget.duration.inMilliseconds * 1.6).round(),
      ),
    );
    _scale = Tween(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    _controller.forward();
  }

  void _onPointerUp(PointerUpEvent _) {
    _controller.reverse();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
