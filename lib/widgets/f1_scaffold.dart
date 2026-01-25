import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class F1Scaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const F1Scaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = appBar == null ? 0.0 : kToolbarHeight + 8;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          Positioned.fill(child: _F1Background()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _F1Background extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orbAlpha = isDark ? 0.45 : 0.12;
    final orbSecondaryAlpha = isDark ? 0.25 : 0.08;
    final stripeStrong = isDark ? 0.25 : 0.08;
    final stripeLight = isDark ? 0.05 : 0.03;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.background,
                colors.backgroundAlt,
              ],
            ),
          ),
        ),
        if (!isDark)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 0.9,
                  colors: [
                    colors.surface.withValues(alpha: 0.9),
                    colors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          top: -140,
          right: -80,
          child: _GlowOrb(
            color: colors.f1Red.withValues(alpha: orbAlpha),
            size: 240,
          ),
        ),
        Positioned(
          bottom: -180,
          left: -120,
          child: _GlowOrb(
            color: colors.f1RedBright.withValues(alpha: orbSecondaryAlpha),
            size: 300,
          ),
        ),
        Positioned(
          top: 120,
          left: -60,
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              width: 200,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    colors.f1Red.withValues(alpha: stripeLight),
                    colors.f1Red.withValues(alpha: stripeStrong),
                    colors.f1Red.withValues(alpha: stripeLight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
