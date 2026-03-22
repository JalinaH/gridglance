import 'package:flutter/material.dart';

/// A widget that animates a number counting up from 0 to [value].
///
/// Supports optional [prefix] and [suffix] text around the number.
/// The animation plays once when the widget first appears.
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final int decimalPlaces;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix,
    this.suffix,
    this.style,
    this.decimalPlaces = 0,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
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
      builder: (context, child) {
        final current = _animation.value * widget.value;
        final formatted = widget.decimalPlaces > 0
            ? current.toStringAsFixed(widget.decimalPlaces)
            : current.round().toString();
        final text = '${widget.prefix ?? ''}$formatted${widget.suffix ?? ''}';
        return Text(text, style: widget.style, textAlign: widget.textAlign);
      },
    );
  }
}
