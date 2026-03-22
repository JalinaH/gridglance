import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Draws a simplified outline of an F1 circuit.
///
/// Pass the [circuitId] from the Race model to select the track layout.
/// Falls back to a generic oval if the circuit is not recognised.
class CircuitTrack extends StatelessWidget {
  final String circuitId;
  final double width;
  final double height;
  final Color? color;
  final double strokeWidth;

  const CircuitTrack({
    super.key,
    required this.circuitId,
    this.width = 120,
    this.height = 80,
    this.color,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trackColor = color ?? colors.f1RedBright;
    return CustomPaint(
      size: Size(width, height),
      painter: _CircuitPainter(
        points: _trackPoints(circuitId),
        color: trackColor,
        strokeWidth: strokeWidth,
        dotColor: colors.f1Red,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _CircuitPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final Color dotColor;

  _CircuitPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 3) return;

    // Scale normalised points (0‑1) to the available size with padding.
    final pad = strokeWidth * 2;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final scaled = points
        .map((p) => Offset(p.dx * w + pad, p.dy * h + pad))
        .toList();

    // Build a smooth closed path using Catmull‑Rom interpolation.
    final path = _smoothPath(scaled);

    // Glow effect.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 4
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 2);
    canvas.drawPath(path, glowPaint);

    // Main track stroke.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    // Start / finish dot.
    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(scaled.first, strokeWidth * 1.8, dotPaint);
    // Inner white dot.
    canvas.drawCircle(
      scaled.first,
      strokeWidth * 0.9,
      Paint()..color = Colors.white,
    );
  }

  Path _smoothPath(List<Offset> pts) {
    final path = Path();
    final n = pts.length;
    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];

      // Only draw the segment from p1→p2.
      const steps = 12;
      for (int s = 1; s <= steps; s++) {
        final t = s / steps;
        final point = _catmullRom(p0, p1, p2, p3, t);
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return Offset(
      0.5 *
          ((2 * p1.dx) +
              (-p0.dx + p2.dx) * t +
              (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
              (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
      0.5 *
          ((2 * p1.dy) +
              (-p0.dy + p2.dy) * t +
              (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
              (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
    );
  }

  @override
  bool shouldRepaint(_CircuitPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ---------------------------------------------------------------------------
// Track outline data — normalised coordinates (0‑1).
//
// Each list traces the circuit outline clockwise from the start/finish line.
// Points are approximate but capture the recognisable shape of each track.
// ---------------------------------------------------------------------------

List<Offset> _trackPoints(String circuitId) {
  final key = circuitId.trim().toLowerCase();
  return _circuits[key] ?? _fallbackOval;
}

// Generic oval used when a circuit has no custom data.
final List<Offset> _fallbackOval = [
  for (int i = 0; i < 24; i++)
    Offset(
      0.5 + 0.45 * _cos(i / 24),
      0.5 + 0.40 * _sin(i / 24),
    ),
];

double _cos(double fraction) {
  return 0.0 + (fraction * 2 * 3.14159265).clamp(-100, 100) == 0
      ? 1.0
      : _cosReal(fraction);
}

double _sin(double fraction) => _sinReal(fraction);

double _cosReal(double f) {
  final a = f * 2 * 3.14159265;
  return a.clamp(-1e10, 1e10) == a ? _dartCos(a) : 0;
}

double _sinReal(double f) {
  final a = f * 2 * 3.14159265;
  return a.clamp(-1e10, 1e10) == a ? _dartSin(a) : 0;
}

double _dartCos(double x) {
  // Use dart:math via dart:ui to avoid extra import.
  return ui.Offset.fromDirection(x).dx;
}

double _dartSin(double x) {
  return ui.Offset.fromDirection(x).dy;
}

const Map<String, List<Offset>> _circuits = {
  // ── Bahrain International Circuit ─────────────────────────────────────
  'bahrain': [
    Offset(0.30, 0.05), Offset(0.70, 0.05), Offset(0.75, 0.10),
    Offset(0.76, 0.20), Offset(0.72, 0.28), Offset(0.78, 0.35),
    Offset(0.80, 0.50), Offset(0.78, 0.60), Offset(0.75, 0.68),
    Offset(0.70, 0.72), Offset(0.65, 0.78), Offset(0.60, 0.85),
    Offset(0.55, 0.90), Offset(0.45, 0.92), Offset(0.35, 0.88),
    Offset(0.28, 0.80), Offset(0.22, 0.70), Offset(0.20, 0.55),
    Offset(0.18, 0.40), Offset(0.20, 0.25), Offset(0.25, 0.15),
  ],

  // ── Jeddah Corniche Circuit ───────────────────────────────────────────
  'jeddah': [
    Offset(0.15, 0.10), Offset(0.25, 0.05), Offset(0.45, 0.08),
    Offset(0.60, 0.05), Offset(0.75, 0.08), Offset(0.85, 0.15),
    Offset(0.90, 0.25), Offset(0.92, 0.40), Offset(0.90, 0.55),
    Offset(0.85, 0.65), Offset(0.78, 0.72), Offset(0.70, 0.78),
    Offset(0.60, 0.85), Offset(0.50, 0.90), Offset(0.40, 0.92),
    Offset(0.30, 0.88), Offset(0.22, 0.80), Offset(0.18, 0.70),
    Offset(0.12, 0.55), Offset(0.10, 0.40), Offset(0.10, 0.25),
  ],

  // ── Albert Park (Melbourne) ───────────────────────────────────────────
  'albert_park': [
    Offset(0.35, 0.08), Offset(0.55, 0.05), Offset(0.70, 0.10),
    Offset(0.80, 0.20), Offset(0.85, 0.35), Offset(0.82, 0.50),
    Offset(0.78, 0.62), Offset(0.70, 0.72), Offset(0.60, 0.80),
    Offset(0.50, 0.88), Offset(0.38, 0.92), Offset(0.25, 0.88),
    Offset(0.18, 0.78), Offset(0.12, 0.65), Offset(0.10, 0.50),
    Offset(0.12, 0.35), Offset(0.18, 0.22), Offset(0.25, 0.12),
  ],

  // ── Suzuka (figure‑8) ─────────────────────────────────────────────────
  'suzuka': [
    Offset(0.20, 0.30), Offset(0.15, 0.15), Offset(0.25, 0.05),
    Offset(0.40, 0.08), Offset(0.50, 0.15), Offset(0.55, 0.25),
    Offset(0.50, 0.35), Offset(0.45, 0.42), // crossover going right
    Offset(0.55, 0.50), Offset(0.65, 0.55), Offset(0.75, 0.48),
    Offset(0.85, 0.40), Offset(0.90, 0.50), Offset(0.88, 0.65),
    Offset(0.80, 0.78), Offset(0.68, 0.85), Offset(0.55, 0.90),
    Offset(0.40, 0.88), Offset(0.30, 0.80), Offset(0.22, 0.70),
    Offset(0.20, 0.55), Offset(0.22, 0.42), // crossover going left
    Offset(0.20, 0.35),
  ],

  // ── Shanghai International Circuit ────────────────────────────────────
  'shanghai': [
    Offset(0.25, 0.10), Offset(0.40, 0.05), Offset(0.55, 0.08),
    Offset(0.65, 0.15), Offset(0.60, 0.25), Offset(0.55, 0.30),
    Offset(0.58, 0.38), Offset(0.70, 0.35), Offset(0.80, 0.30),
    Offset(0.88, 0.38), Offset(0.90, 0.52), Offset(0.85, 0.65),
    Offset(0.78, 0.75), Offset(0.65, 0.82), Offset(0.50, 0.90),
    Offset(0.35, 0.92), Offset(0.22, 0.85), Offset(0.15, 0.72),
    Offset(0.10, 0.55), Offset(0.12, 0.38), Offset(0.18, 0.22),
  ],

  // ── Miami International Autodrome ─────────────────────────────────────
  'miami': [
    Offset(0.20, 0.15), Offset(0.40, 0.08), Offset(0.60, 0.05),
    Offset(0.78, 0.10), Offset(0.85, 0.22), Offset(0.88, 0.38),
    Offset(0.82, 0.55), Offset(0.72, 0.65), Offset(0.60, 0.72),
    Offset(0.50, 0.80), Offset(0.42, 0.88), Offset(0.30, 0.90),
    Offset(0.20, 0.85), Offset(0.15, 0.72), Offset(0.12, 0.55),
    Offset(0.10, 0.40), Offset(0.14, 0.28),
  ],

  // ── Imola (Autodromo Enzo e Dino Ferrari) ─────────────────────────────
  'imola': [
    Offset(0.30, 0.15), Offset(0.50, 0.08), Offset(0.68, 0.12),
    Offset(0.78, 0.22), Offset(0.85, 0.35), Offset(0.88, 0.50),
    Offset(0.82, 0.62), Offset(0.72, 0.72), Offset(0.58, 0.80),
    Offset(0.45, 0.88), Offset(0.32, 0.90), Offset(0.22, 0.82),
    Offset(0.15, 0.68), Offset(0.10, 0.52), Offset(0.12, 0.38),
    Offset(0.18, 0.25),
  ],

  // ── Monaco ────────────────────────────────────────────────────────────
  'monaco': [
    Offset(0.20, 0.25), Offset(0.35, 0.10), Offset(0.55, 0.05),
    Offset(0.72, 0.08), Offset(0.82, 0.18), Offset(0.88, 0.32),
    Offset(0.85, 0.48), Offset(0.78, 0.58), Offset(0.70, 0.65),
    Offset(0.75, 0.75), Offset(0.72, 0.85), Offset(0.60, 0.92),
    Offset(0.45, 0.90), Offset(0.32, 0.82), Offset(0.22, 0.72),
    Offset(0.15, 0.60), Offset(0.12, 0.45), Offset(0.15, 0.35),
  ],

  // ── Circuit de Barcelona‑Catalunya ────────────────────────────────────
  'catalunya': [
    Offset(0.25, 0.12), Offset(0.45, 0.05), Offset(0.65, 0.08),
    Offset(0.78, 0.15), Offset(0.85, 0.28), Offset(0.88, 0.42),
    Offset(0.82, 0.55), Offset(0.72, 0.65), Offset(0.60, 0.75),
    Offset(0.50, 0.82), Offset(0.38, 0.90), Offset(0.25, 0.88),
    Offset(0.15, 0.78), Offset(0.10, 0.60), Offset(0.12, 0.42),
    Offset(0.18, 0.25),
  ],

  // ── Circuit Gilles Villeneuve (Montréal) ──────────────────────────────
  'villeneuve': [
    Offset(0.10, 0.40), Offset(0.15, 0.20), Offset(0.25, 0.10),
    Offset(0.40, 0.05), Offset(0.58, 0.08), Offset(0.72, 0.12),
    Offset(0.82, 0.18), Offset(0.90, 0.30), Offset(0.88, 0.48),
    Offset(0.85, 0.60), Offset(0.90, 0.72), Offset(0.88, 0.82),
    Offset(0.78, 0.90), Offset(0.60, 0.92), Offset(0.42, 0.88),
    Offset(0.28, 0.80), Offset(0.18, 0.68), Offset(0.12, 0.55),
  ],

  // ── Red Bull Ring (Spielberg) ─────────────────────────────────────────
  'red_bull_ring': [
    Offset(0.20, 0.80), Offset(0.20, 0.55), Offset(0.22, 0.35),
    Offset(0.28, 0.18), Offset(0.40, 0.08), Offset(0.55, 0.05),
    Offset(0.70, 0.10), Offset(0.80, 0.22), Offset(0.85, 0.38),
    Offset(0.82, 0.55), Offset(0.78, 0.68), Offset(0.70, 0.78),
    Offset(0.58, 0.88), Offset(0.42, 0.92), Offset(0.30, 0.88),
  ],

  // ── Silverstone ───────────────────────────────────────────────────────
  'silverstone': [
    Offset(0.30, 0.10), Offset(0.50, 0.05), Offset(0.65, 0.08),
    Offset(0.75, 0.15), Offset(0.82, 0.22), Offset(0.88, 0.32),
    Offset(0.85, 0.45), Offset(0.78, 0.52), Offset(0.70, 0.48),
    Offset(0.65, 0.55), Offset(0.72, 0.65), Offset(0.80, 0.75),
    Offset(0.75, 0.85), Offset(0.62, 0.92), Offset(0.48, 0.90),
    Offset(0.35, 0.85), Offset(0.25, 0.75), Offset(0.18, 0.62),
    Offset(0.12, 0.48), Offset(0.15, 0.32), Offset(0.20, 0.20),
  ],

  // ── Hungaroring ───────────────────────────────────────────────────────
  'hungaroring': [
    Offset(0.25, 0.15), Offset(0.42, 0.05), Offset(0.60, 0.08),
    Offset(0.72, 0.15), Offset(0.80, 0.28), Offset(0.85, 0.42),
    Offset(0.82, 0.58), Offset(0.75, 0.70), Offset(0.65, 0.80),
    Offset(0.52, 0.88), Offset(0.38, 0.92), Offset(0.25, 0.85),
    Offset(0.18, 0.72), Offset(0.12, 0.55), Offset(0.15, 0.38),
    Offset(0.20, 0.25),
  ],

  // ── Spa‑Francorchamps ─────────────────────────────────────────────────
  'spa': [
    Offset(0.10, 0.70), Offset(0.12, 0.50), Offset(0.15, 0.35),
    Offset(0.20, 0.22), Offset(0.30, 0.12), Offset(0.42, 0.05),
    Offset(0.55, 0.08), Offset(0.65, 0.15), Offset(0.72, 0.25),
    Offset(0.78, 0.38), Offset(0.85, 0.48), Offset(0.90, 0.55),
    Offset(0.88, 0.68), Offset(0.82, 0.78), Offset(0.72, 0.85),
    Offset(0.58, 0.90), Offset(0.42, 0.92), Offset(0.28, 0.88),
    Offset(0.18, 0.80),
  ],

  // ── Zandvoort ─────────────────────────────────────────────────────────
  'zandvoort': [
    Offset(0.25, 0.20), Offset(0.40, 0.08), Offset(0.58, 0.05),
    Offset(0.72, 0.10), Offset(0.82, 0.22), Offset(0.88, 0.38),
    Offset(0.85, 0.55), Offset(0.78, 0.68), Offset(0.65, 0.78),
    Offset(0.50, 0.85), Offset(0.35, 0.90), Offset(0.22, 0.82),
    Offset(0.15, 0.68), Offset(0.10, 0.50), Offset(0.15, 0.35),
  ],

  // ── Monza ─────────────────────────────────────────────────────────────
  'monza': [
    Offset(0.30, 0.12), Offset(0.50, 0.05), Offset(0.70, 0.08),
    Offset(0.82, 0.18), Offset(0.88, 0.35), Offset(0.85, 0.55),
    Offset(0.80, 0.65), Offset(0.72, 0.58), Offset(0.68, 0.65),
    Offset(0.72, 0.75), Offset(0.65, 0.85), Offset(0.50, 0.92),
    Offset(0.35, 0.90), Offset(0.22, 0.82), Offset(0.15, 0.68),
    Offset(0.12, 0.50), Offset(0.15, 0.35), Offset(0.20, 0.22),
  ],

  // ── Baku City Circuit ─────────────────────────────────────────────────
  'baku': [
    Offset(0.10, 0.50), Offset(0.12, 0.30), Offset(0.18, 0.15),
    Offset(0.30, 0.08), Offset(0.50, 0.05), Offset(0.68, 0.08),
    Offset(0.80, 0.15), Offset(0.88, 0.28), Offset(0.90, 0.45),
    Offset(0.88, 0.60), Offset(0.82, 0.72), Offset(0.70, 0.82),
    Offset(0.55, 0.90), Offset(0.40, 0.92), Offset(0.28, 0.88),
    Offset(0.18, 0.78), Offset(0.12, 0.65),
  ],

  // ── Marina Bay (Singapore) ────────────────────────────────────────────
  'marina_bay': [
    Offset(0.20, 0.18), Offset(0.38, 0.08), Offset(0.55, 0.05),
    Offset(0.70, 0.10), Offset(0.80, 0.18), Offset(0.85, 0.30),
    Offset(0.82, 0.42), Offset(0.75, 0.50), Offset(0.80, 0.60),
    Offset(0.85, 0.72), Offset(0.78, 0.82), Offset(0.65, 0.90),
    Offset(0.50, 0.92), Offset(0.35, 0.88), Offset(0.25, 0.80),
    Offset(0.18, 0.68), Offset(0.12, 0.52), Offset(0.15, 0.35),
  ],

  // ── Circuit of the Americas (COTA) ────────────────────────────────────
  'americas': [
    Offset(0.25, 0.12), Offset(0.32, 0.05), Offset(0.42, 0.10),
    Offset(0.48, 0.18), Offset(0.55, 0.12), Offset(0.65, 0.08),
    Offset(0.78, 0.12), Offset(0.85, 0.22), Offset(0.88, 0.38),
    Offset(0.82, 0.52), Offset(0.75, 0.60), Offset(0.80, 0.72),
    Offset(0.78, 0.82), Offset(0.68, 0.90), Offset(0.52, 0.92),
    Offset(0.38, 0.88), Offset(0.25, 0.78), Offset(0.18, 0.65),
    Offset(0.12, 0.48), Offset(0.15, 0.32), Offset(0.20, 0.20),
  ],

  // ── Autódromo Hermanos Rodríguez (Mexico City) ────────────────────────
  'rodriguez': [
    Offset(0.22, 0.15), Offset(0.40, 0.05), Offset(0.60, 0.08),
    Offset(0.75, 0.15), Offset(0.82, 0.28), Offset(0.85, 0.42),
    Offset(0.80, 0.55), Offset(0.72, 0.62), Offset(0.65, 0.58),
    Offset(0.60, 0.65), Offset(0.65, 0.78), Offset(0.58, 0.88),
    Offset(0.42, 0.92), Offset(0.28, 0.85), Offset(0.18, 0.72),
    Offset(0.12, 0.55), Offset(0.15, 0.38), Offset(0.18, 0.25),
  ],

  // ── Interlagos (São Paulo) ────────────────────────────────────────────
  'interlagos': [
    Offset(0.70, 0.15), Offset(0.82, 0.22), Offset(0.88, 0.38),
    Offset(0.85, 0.55), Offset(0.78, 0.68), Offset(0.65, 0.78),
    Offset(0.50, 0.85), Offset(0.35, 0.90), Offset(0.22, 0.82),
    Offset(0.15, 0.68), Offset(0.10, 0.50), Offset(0.15, 0.35),
    Offset(0.22, 0.22), Offset(0.35, 0.12), Offset(0.50, 0.08),
  ],

  // ── Las Vegas Strip Circuit ───────────────────────────────────────────
  'las_vegas': [
    Offset(0.15, 0.20), Offset(0.15, 0.08), Offset(0.35, 0.05),
    Offset(0.55, 0.05), Offset(0.75, 0.05), Offset(0.85, 0.12),
    Offset(0.88, 0.28), Offset(0.85, 0.42), Offset(0.78, 0.52),
    Offset(0.82, 0.65), Offset(0.85, 0.78), Offset(0.78, 0.88),
    Offset(0.60, 0.92), Offset(0.40, 0.90), Offset(0.25, 0.82),
    Offset(0.15, 0.68), Offset(0.12, 0.50), Offset(0.12, 0.35),
  ],

  // ── Losail International Circuit (Qatar) ──────────────────────────────
  'losail': [
    Offset(0.22, 0.12), Offset(0.42, 0.05), Offset(0.62, 0.08),
    Offset(0.75, 0.18), Offset(0.82, 0.32), Offset(0.85, 0.48),
    Offset(0.80, 0.62), Offset(0.72, 0.72), Offset(0.60, 0.80),
    Offset(0.48, 0.88), Offset(0.35, 0.92), Offset(0.22, 0.85),
    Offset(0.15, 0.72), Offset(0.10, 0.55), Offset(0.12, 0.38),
    Offset(0.18, 0.22),
  ],

  // ── Yas Marina (Abu Dhabi) ────────────────────────────────────────────
  'yas_marina': [
    Offset(0.30, 0.10), Offset(0.50, 0.05), Offset(0.68, 0.08),
    Offset(0.78, 0.18), Offset(0.85, 0.30), Offset(0.88, 0.45),
    Offset(0.85, 0.58), Offset(0.78, 0.68), Offset(0.82, 0.78),
    Offset(0.78, 0.88), Offset(0.65, 0.92), Offset(0.48, 0.90),
    Offset(0.35, 0.85), Offset(0.22, 0.75), Offset(0.15, 0.62),
    Offset(0.10, 0.48), Offset(0.12, 0.32), Offset(0.20, 0.18),
  ],
};
