import 'dart:async';

import 'package:flutter/material.dart';

class CountdownText extends StatefulWidget {
  final DateTime? target;
  final TextStyle? style;
  final String prefix;
  final String startedLabel;
  final bool hideIfPast;
  final Duration refreshInterval;

  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.prefix = 'Starts in',
    this.startedLabel = 'Started',
    this.hideIfPast = true,
    this.refreshInterval = const Duration(minutes: 1),
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _wasPositive = true;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _remaining = _computeRemaining();
    _wasPositive = !_remaining.isNegative && _remaining.inMinutes > 0;
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (!mounted) {
        return;
      }
      final prev = _remaining;
      setState(() {
        _remaining = _computeRemaining();
      });
      _checkZeroCrossing(prev);
    });
  }

  void _checkZeroCrossing(Duration prev) {
    final isZeroOrPast = _remaining.isNegative || _remaining.inMinutes <= 0;
    if (_wasPositive && isZeroOrPast) {
      _pulseController.repeat(reverse: true);
    }
    _wasPositive = !isZeroOrPast;
  }

  @override
  void didUpdateWidget(CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _timer?.cancel();
      _pulseController.reset();
      _remaining = _computeRemaining();
      _wasPositive = !_remaining.isNegative && _remaining.inMinutes > 0;
      _timer = Timer.periodic(widget.refreshInterval, (_) {
        if (!mounted) {
          return;
        }
        final prev = _remaining;
        setState(() {
          _remaining = _computeRemaining();
        });
        _checkZeroCrossing(prev);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Duration _computeRemaining() {
    final target = widget.target;
    if (target == null) {
      return Duration.zero;
    }
    return target.difference(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    if (target == null) {
      return const SizedBox.shrink();
    }
    if (_remaining.isNegative && widget.hideIfPast) {
      return const SizedBox.shrink();
    }
    final label = _formatCountdown(_remaining);
    final text = Text(label, style: widget.style);
    if (_pulseController.isAnimating) {
      return ScaleTransition(scale: _pulseScale, child: text);
    }
    return text;
  }

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) {
      return widget.startedLabel;
    }
    if (duration.inMinutes <= 0) {
      return 'Starting now';
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) {
      return '${widget.prefix} ${days}d ${hours}h';
    }
    if (duration.inHours > 0) {
      return '${widget.prefix} ${hours}h ${minutes}m';
    }
    return '${widget.prefix} ${minutes}m';
  }
}
