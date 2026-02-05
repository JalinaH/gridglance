import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PointsTrendChart extends StatelessWidget {
  final List<double> points;
  final List<String> labels;
  final double height;

  const PointsTrendChart({
    super.key,
    required this.points,
    required this.labels,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (points.length < 2) {
      return Text(
        'Not enough data to chart yet.',
        style: TextStyle(color: colors.textMuted, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _PointsTrendPainter(
              points: points,
              lineColor: colors.f1Red,
              fillColor: colors.f1Red,
              gridColor: colors.border,
            ),
            child: Container(),
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Text(
              labels.first,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
            Spacer(),
            Text(
              labels.last,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _PointsTrendPainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  const _PointsTrendPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }
    final maxPoint = points.reduce(max);
    final normalizedMax = maxPoint <= 0 ? 1.0 : maxPoint;
    final dx = size.width / (points.length - 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - (points[i] / normalizedMax) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final midY = size.height * 0.5;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor.withValues(alpha: 0.3),
          fillColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - (points[i] / normalizedMax) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PointsTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.fillColor != fillColor;
  }
}
