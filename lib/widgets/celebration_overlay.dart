import 'dart:math';
import 'package:flutter/material.dart';

/// Shows a brief celebratory burst of animated particles radiating from the
/// center of the screen. Designed for key moments like saving a prediction or
/// enabling a notification.
///
/// Usage: call [CelebrationOverlay.show] from any context.
class CelebrationOverlay {
  CelebrationOverlay._();

  static OverlayEntry? _activeEntry;

  /// Plays a short celebration animation.
  ///
  /// [variant] controls the visual style:
  /// - [CelebrationType.confetti] — colourful falling confetti (prediction saved)
  /// - [CelebrationType.pulse] — a single expanding ring pulse (notification set)
  static void show(
    BuildContext context, {
    CelebrationType variant = CelebrationType.confetti,
  }) {
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationAnimation(
        variant: variant,
        onComplete: () {
          entry.remove();
          if (_activeEntry == entry) _activeEntry = null;
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }
}

enum CelebrationType { confetti, pulse }

class _CelebrationAnimation extends StatefulWidget {
  final CelebrationType variant;
  final VoidCallback onComplete;

  const _CelebrationAnimation({
    required this.variant,
    required this.onComplete,
  });

  @override
  State<_CelebrationAnimation> createState() => _CelebrationAnimationState();
}

class _CelebrationAnimationState extends State<_CelebrationAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.variant == CelebrationType.confetti
          ? Duration(milliseconds: 1200)
          : Duration(milliseconds: 800),
    )
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: widget.variant == CelebrationType.confetti
          ? _ConfettiBurst(animation: _controller)
          : _PulseRing(animation: _controller),
    );
  }
}

// ---------------------------------------------------------------------------
// Confetti burst — colourful particles radiating outward then fading
// ---------------------------------------------------------------------------

class _ConfettiBurst extends StatelessWidget {
  final Animation<double> animation;
  static const _particleCount = 24;

  const _ConfettiBurst({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.sizeOf(context),
          painter: _ConfettiPainter(
            progress: animation.value,
            particleCount: _particleCount,
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final int particleCount;
  static final _random = Random(42);
  static final List<_Particle> _particles = [];

  _ConfettiPainter({required this.progress, required this.particleCount}) {
    if (_particles.length != particleCount) {
      _particles.clear();
      for (int i = 0; i < particleCount; i++) {
        _particles.add(_Particle.random(_random));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final maxRadius = size.height * 0.35;

    for (final particle in _particles) {
      final t = (progress * (1.0 + particle.speed * 0.3)).clamp(0.0, 1.0);
      final ease = Curves.easeOutCubic.transform(t);
      final fade = (1.0 - Curves.easeInQuad.transform(t)).clamp(0.0, 1.0);

      final radius = ease * maxRadius * particle.distance;
      final x = center.dx + cos(particle.angle) * radius;
      final y = center.dy + sin(particle.angle) * radius + (ease * 40 * particle.gravity);

      final paint = Paint()
        ..color = particle.color.withValues(alpha: fade)
        ..style = PaintingStyle.fill;

      final particleSize = particle.size * (1.0 - ease * 0.4);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(ease * particle.spin * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: particleSize, height: particleSize * 0.6),
          Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  final double angle;
  final double distance;
  final double speed;
  final double gravity;
  final double spin;
  final double size;
  final Color color;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.gravity,
    required this.spin,
    required this.size,
    required this.color,
  });

  static const _colors = [
    Color(0xFFE10600), // F1 red
    Color(0xFFFF3B30), // F1 bright red
    Color(0xFFFFCC00), // Gold
    Color(0xFF34C759), // Green
    Color(0xFF5AC8FA), // Blue
    Color(0xFFFF9500), // Orange
    Color(0xFFAF52DE), // Purple
    Colors.white,
  ];

  factory _Particle.random(Random rng) {
    return _Particle(
      angle: rng.nextDouble() * 2 * pi,
      distance: 0.5 + rng.nextDouble() * 0.5,
      speed: 0.6 + rng.nextDouble() * 0.4,
      gravity: rng.nextDouble(),
      spin: 1.0 + rng.nextDouble() * 3.0,
      size: 5.0 + rng.nextDouble() * 7.0,
      color: _colors[rng.nextInt(_colors.length)],
    );
  }
}

// ---------------------------------------------------------------------------
// Pulse ring — expanding circle that fades out
// ---------------------------------------------------------------------------

class _PulseRing extends StatelessWidget {
  final Animation<double> animation;

  const _PulseRing({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.sizeOf(context),
          painter: _PulsePainter(progress: animation.value),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;

  _PulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final maxRadius = size.width * 0.4;
    final ease = Curves.easeOutCubic.transform(progress);
    final fade = (1.0 - Curves.easeInQuad.transform(progress)).clamp(0.0, 1.0);

    // Outer ring
    final paint = Paint()
      ..color = Color(0xFFE10600).withValues(alpha: fade * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1.0 - ease * 0.5);
    canvas.drawCircle(center, ease * maxRadius, paint);

    // Inner glow
    final glowPaint = Paint()
      ..color = Color(0xFFFF3B30).withValues(alpha: fade * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, ease * maxRadius * 0.7, glowPaint);

    // Center dot
    final dotFade = (1.0 - progress * 2).clamp(0.0, 1.0);
    if (dotFade > 0) {
      final dotPaint = Paint()
        ..color = Color(0xFFE10600).withValues(alpha: dotFade * 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 6.0 * (1.0 - ease), dotPaint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.progress != progress;
}
