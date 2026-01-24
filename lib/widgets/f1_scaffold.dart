import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class F1Scaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const F1Scaffold({
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
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.background,
                AppTheme.backgroundAlt,
              ],
            ),
          ),
        ),
        Positioned(
          top: -140,
          right: -80,
          child: _GlowOrb(
            color: AppTheme.f1Red.withOpacity(0.45),
            size: 240,
          ),
        ),
        Positioned(
          bottom: -180,
          left: -120,
          child: _GlowOrb(
            color: AppTheme.f1RedBright.withOpacity(0.25),
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
                    AppTheme.f1Red.withOpacity(0.05),
                    AppTheme.f1Red.withOpacity(0.25),
                    AppTheme.f1Red.withOpacity(0.05),
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
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}
