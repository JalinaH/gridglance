import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HeadToHeadPointsChart extends StatelessWidget {
  final List<double> firstPoints;
  final List<double> secondPoints;
  final List<String> labels;
  final String firstLabel;
  final String secondLabel;
  final double height;

  const HeadToHeadPointsChart({
    super.key,
    required this.firstPoints,
    required this.secondPoints,
    required this.labels,
    required this.firstLabel,
    required this.secondLabel,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final length = min(
      min(firstPoints.length, secondPoints.length),
      labels.length,
    );
    if (length < 2) {
      return Text(
        'Not enough trend data yet.',
        style: TextStyle(color: colors.textMuted, fontSize: 12),
      );
    }
    final chartFirst = firstPoints.take(length).toList();
    final chartSecond = secondPoints.take(length).toList();
    final chartLabels = labels.take(length).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: height,
          child: CustomPaint(
            painter: _HeadToHeadPainter(
              first: chartFirst,
              second: chartSecond,
              firstColor: colors.f1Red,
              secondColor: colors.f1RedBright.withValues(alpha: 0.75),
              gridColor: colors.border,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            _LegendDot(color: colors.f1Red, label: firstLabel),
            SizedBox(width: 12),
            _LegendDot(
              color: colors.f1RedBright.withValues(alpha: 0.75),
              label: secondLabel,
            ),
          ],
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Text(
              chartLabels.isEmpty ? '' : chartLabels.first,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
            Spacer(),
            Text(
              chartLabels.isEmpty ? '' : chartLabels.last,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeadToHeadPainter extends CustomPainter {
  final List<double> first;
  final List<double> second;
  final Color firstColor;
  final Color secondColor;
  final Color gridColor;

  const _HeadToHeadPainter({
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (first.length < 2 || second.length < 2) {
      return;
    }
    final maxValue = [first, second]
        .expand((series) => series)
        .fold<double>(0, (maxSoFar, value) => max(maxSoFar, value));
    final normalizedMax = maxValue <= 0 ? 1.0 : maxValue;
    final stepX = size.width / (first.length - 1);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final topY = size.height * 0.15;
    final midY = size.height * 0.5;
    final bottomY = size.height * 0.85;
    canvas.drawLine(Offset(0, topY), Offset(size.width, topY), gridPaint);
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);
    canvas.drawLine(Offset(0, bottomY), Offset(size.width, bottomY), gridPaint);

    _drawSeries(
      canvas: canvas,
      size: size,
      points: first,
      maxValue: normalizedMax,
      stepX: stepX,
      color: firstColor,
    );
    _drawSeries(
      canvas: canvas,
      size: size,
      points: second,
      maxValue: normalizedMax,
      stepX: stepX,
      color: secondColor,
    );
  }

  void _drawSeries({
    required Canvas canvas,
    required Size size,
    required List<double> points,
    required double maxValue,
    required double stepX,
    required Color color,
  }) {
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = index * stepX;
      final y = size.height - (points[index] / maxValue) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (var index = 0; index < points.length; index++) {
      final x = index * stepX;
      final y = size.height - (points[index] / maxValue) * size.height;
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeadToHeadPainter oldDelegate) {
    return oldDelegate.first != first ||
        oldDelegate.second != second ||
        oldDelegate.firstColor != firstColor ||
        oldDelegate.secondColor != secondColor ||
        oldDelegate.gridColor != gridColor;
  }
}
