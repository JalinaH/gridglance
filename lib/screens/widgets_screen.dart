import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../services/widget_update_service.dart';
import '../theme/app_theme.dart';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  bool _adding = false;
  String? _statusMessage;

  Future<void> _addDriverWidget() async {
    setState(() {
      _adding = true;
      _statusMessage = null;
    });

    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (!supported) {
        if (mounted) {
          setState(() {
            _statusMessage = "Widget pinning not supported. Use widget picker.";
          });
        }
        return;
      }
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName:
            WidgetUpdateService.androidQualifiedDriverWidgetProvider,
      );
      if (mounted) {
        setState(() {
          _statusMessage = "Widget add request sent";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = "Failed to request widget";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          "Widgets",
          style: TextStyle(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 16),
        _buildWidgetCard(
          context,
          preview: _DriverStandingsPreview(),
          actionLabel: "Add widget",
          onAction: _adding ? null : _addDriverWidget,
          statusMessage: _statusMessage,
        ),
      ],
    );
  }

  Widget _buildWidgetCard(
    BuildContext context, {
    required Widget preview,
    required String actionLabel,
    required VoidCallback? onAction,
    String? statusMessage,
  }) {
    final colors = AppColors.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.06,
            ),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          if (statusMessage != null) ...[
            SizedBox(height: 8),
            Text(
              statusMessage,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
          SizedBox(height: 10),
          SizedBox(
            height: 34,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.f1Red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onAction,
              child: Text(
                _adding ? "Adding..." : actionLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStandingsPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 18 / 10,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.backgroundAlt,
              colors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -32,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.f1RedBright.withValues(alpha: isDark ? 0.35 : 0.2),
                      colors.f1Red.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceAlt.withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 3,
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.f1Red, colors.f1RedBright],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "DRIVER STANDINGS",
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt.withValues(
                            alpha: isDark ? 0.9 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          "2024",
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Top 3 drivers",
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 10),
                  _StandingsRow(
                    position: "1",
                    name: "Driver One",
                    points: "413 pts",
                    highlight: true,
                  ),
                  SizedBox(height: 6),
                  _StandingsRow(
                    position: "2",
                    name: "Driver Two",
                    points: "370 pts",
                  ),
                  SizedBox(height: 6),
                  _StandingsRow(
                    position: "3",
                    name: "Driver Three",
                    points: "312 pts",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingsRow extends StatelessWidget {
  final String position;
  final String name;
  final String points;
  final bool highlight;

  const _StandingsRow({
    required this.position,
    required this.name,
    required this.points,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final badgeFill = highlight
        ? colors.f1Red.withValues(alpha: 0.95)
        : colors.surfaceAlt;
    final rowBackground = highlight
        ? colors.surfaceAlt.withValues(alpha: 0.7)
        : Colors.transparent;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: rowBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? colors.border.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeFill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              position,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: highlight ? onSurface : colors.textMuted,
                fontSize: 11,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            points,
            style: TextStyle(
              color: highlight ? onSurface : colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
