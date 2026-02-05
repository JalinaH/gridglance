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

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _remaining = _computeRemaining();
      });
    });
  }

  @override
  void didUpdateWidget(CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _timer?.cancel();
      _remaining = _computeRemaining();
      _timer = Timer.periodic(widget.refreshInterval, (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _remaining = _computeRemaining();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      return SizedBox.shrink();
    }
    if (_remaining.isNegative && widget.hideIfPast) {
      return SizedBox.shrink();
    }
    final label = _formatCountdown(_remaining);
    return Text(label, style: widget.style);
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
