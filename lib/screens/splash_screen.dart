import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _f1Red = Color(0xFFE10600);
  static const Color _bgDark = Color(0xFF0C0F14);

  late final AnimationController _logoController;
  late final AnimationController _glowController;
  late final AnimationController _lightsController;
  late final AnimationController _textController;
  late final AnimationController _exitController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glowPulse;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _exitOpacity;

  // 5 lights for the F1 starting sequence
  final List<Animation<double>> _lightAnimations = [];

  @override
  void initState() {
    super.initState();

    // Logo entrance: scale up + fade in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    // Glow pulsing behind logo
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 5 starting lights that turn on sequentially
    _lightsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    for (int i = 0; i < 5; i++) {
      final start = i * 0.18;
      final end = (start + 0.12).clamp(0.0, 1.0);
      _lightAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _lightsController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
    }

    // Text fade in + slide up
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Exit animation
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Logo appears
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    // Glow starts pulsing
    _glowController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 300));

    // Lights turn on one by one
    _lightsController.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    // Text appears
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));

    // Exit
    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _lightsController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitController,
      builder: (context, child) {
        return Opacity(
          opacity: _exitOpacity.value,
          child: Scaffold(
            backgroundColor: _bgDark,
            body: Stack(
              children: [
                // Animated racing stripes background
                _RacingStripes(animation: _lightsController),

                // Red glow behind logo
                Center(
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, _) {
                      return Container(
                        width: 250 + (_glowPulse.value * 60),
                        height: 250 + (_glowPulse.value * 60),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _f1Red.withValues(
                                alpha: 0.15 * _glowPulse.value,
                              ),
                              blurRadius: 80 + (_glowPulse.value * 40),
                              spreadRadius: 20 + (_glowPulse.value * 20),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Main content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo with scale + fade animation
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, _) {
                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _f1Red.withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: Image.asset(
                                    'lib/assets/logo/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // 5 starting lights
                      AnimatedBuilder(
                        animation: _lightsController,
                        builder: (context, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (i) {
                              final value = _lightAnimations[i].value;
                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.lerp(
                                    const Color(0xFF2A2A2A),
                                    _f1Red,
                                    value,
                                  ),
                                  boxShadow: value > 0.1
                                      ? [
                                          BoxShadow(
                                            color: _f1Red.withValues(
                                              alpha: 0.6 * value,
                                            ),
                                            blurRadius: 12 * value,
                                            spreadRadius: 2 * value,
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // App name with slide + fade
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'GRIDGLANCE',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 36,
                                  letterSpacing: 6,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'YOUR F1 COMPANION',
                                style: GoogleFonts.titilliumWeb(
                                  fontSize: 12,
                                  letterSpacing: 4,
                                  color: _f1Red.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Diagonal racing stripes that animate in from the bottom-left
class _RacingStripes extends StatelessWidget {
  final Animation<double> animation;

  const _RacingStripes({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _StripesPainter(animation.value),
        );
      },
    );
  }
}

class _StripesPainter extends CustomPainter {
  final double progress;

  _StripesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.05) return;

    final stripes = [
      _StripeData(0.85, 0.08, const Color(0xFFE10600), 0.06),
      _StripeData(0.80, 0.04, const Color(0xFFE10600), 0.12),
      _StripeData(0.75, 0.06, const Color(0xFF1C2430), 0.18),
      _StripeData(0.90, 0.03, const Color(0xFFE10600), 0.25),
      _StripeData(0.70, 0.05, const Color(0xFF1C2430), 0.30),
    ];

    for (final stripe in stripes) {
      final adjustedProgress =
          ((progress - stripe.delay) / (1.0 - stripe.delay)).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final easedProgress =
          Curves.easeOutCubic.transform(adjustedProgress) * 0.5;

      final paint = Paint()
        ..color = stripe.color.withValues(alpha: 0.15 * easedProgress * 2)
        ..style = PaintingStyle.fill;

      final yStart = size.height * stripe.yPosition;
      final path = Path();
      final xEnd = size.width * easedProgress;

      path.moveTo(0, yStart);
      path.lineTo(xEnd, yStart - size.height * 0.15);
      path.lineTo(xEnd, yStart - size.height * 0.15 + size.height * stripe.thickness);
      path.lineTo(0, yStart + size.height * stripe.thickness);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StripeData {
  final double yPosition;
  final double thickness;
  final Color color;
  final double delay;

  _StripeData(this.yPosition, this.thickness, this.color, this.delay);
}
