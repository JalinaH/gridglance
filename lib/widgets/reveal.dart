import 'package:flutter/material.dart';

class Reveal extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const Reveal({
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 550),
  });

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 90 * index);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final offset = 18 * (1 - value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
