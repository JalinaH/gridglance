import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

class SwipeActionWrapper extends StatefulWidget {
  final Widget child;

  /// Primary action (swipe right).
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final VoidCallback onSwipe;

  /// Optional secondary action (swipe left).
  final IconData? secondaryIcon;
  final String? secondaryLabel;
  final Color? secondaryBackgroundColor;
  final VoidCallback? onSecondarySwipe;

  const SwipeActionWrapper({
    super.key,
    required this.child,
    required this.icon,
    required this.label,
    this.backgroundColor,
    required this.onSwipe,
    this.secondaryIcon,
    this.secondaryLabel,
    this.secondaryBackgroundColor,
    this.onSecondarySwipe,
  });

  @override
  State<SwipeActionWrapper> createState() => _SwipeActionWrapperState();
}

class _SwipeActionWrapperState extends State<SwipeActionWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0;
  static const _threshold = 80.0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250),
    );
    _animation = _controller.drive(Tween(begin: 0.0, end: 0.0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final hasSecondary =
        widget.onSecondarySwipe != null && widget.secondaryIcon != null;
    final delta = details.primaryDelta ?? 0;

    if (!hasSecondary && _dragExtent + delta < 0) return;

    setState(() {
      _dragExtent = (_dragExtent + delta).clamp(
        hasSecondary ? -160.0 : 0.0,
        160.0,
      );
    });

    if (!_triggered && _dragExtent.abs() >= _threshold) {
      _triggered = true;
      Haptics.medium();
    } else if (_triggered && _dragExtent.abs() < _threshold) {
      _triggered = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragExtent >= _threshold) {
      widget.onSwipe();
    } else if (_dragExtent <= -_threshold && widget.onSecondarySwipe != null) {
      widget.onSecondarySwipe!();
    }

    _animation = Tween(
      begin: _dragExtent,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragExtent = 0;
          _triggered = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final primaryBg = widget.backgroundColor ?? colors.f1Red;
    final secondaryBg =
        widget.secondaryBackgroundColor ?? Colors.amber.shade700;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final offset = _controller.isAnimating ? _animation.value : _dragExtent;
        final isRight = offset > 0;
        final progress = (offset.abs() / _threshold).clamp(0.0, 1.0);

        return Stack(
          children: [
            if (offset != 0)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isRight ? primaryBg : secondaryBg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: isRight
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Opacity(
                        opacity: progress,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: isRight
                              ? [
                                  Icon(
                                    widget.icon,
                                    color: Colors.white,
                                    size: 22 + (progress * 4),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    widget.label,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ]
                              : [
                                  Text(
                                    widget.secondaryLabel ?? '',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    widget.secondaryIcon,
                                    color: Colors.white,
                                    size: 22 + (progress * 4),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: Offset(offset, 0),
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}
