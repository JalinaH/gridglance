import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/f1_scaffold.dart';
import '../services/widget_update_service.dart';
import 'about_screen.dart';
import 'home_screen.dart';
import 'widgets_screen.dart';

class MainShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetUpdateService.startDriverStandingsAutoRefresh();
  }

  @override
  void dispose() {
    WidgetUpdateService.stopDriverStandingsAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final wide = isWideScreen(context);
    final body = IndexedStack(
      index: _index,
      children: [
        HomeScreen(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          showAppBar: false,
        ),
        WidgetsScreen(),
        AboutScreen(),
      ],
    );
    return F1Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_index)),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: colors.f1RedBright,
            ),
            onPressed: () {
              Haptics.light();
              widget.onToggleTheme();
            },
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                _buildNavigationRail(context),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colors.border,
                ),
                Expanded(child: body),
              ],
            )
          : Column(
              children: [
                Expanded(child: body),
                _buildNavigationBar(context),
              ],
            ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.surfaceAlt.withValues(alpha: 0.98),
            colors.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            SizedBox(height: 12),
            _buildRailItem(
              index: 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              activeColor: colors.f1RedBright,
              inactiveColor: colors.textMuted,
              textColor: onSurface,
            ),
            SizedBox(height: 8),
            _buildRailItem(
              index: 1,
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              label: 'Widgets',
              activeColor: colors.f1RedBright,
              inactiveColor: colors.textMuted,
              textColor: onSurface,
            ),
            SizedBox(height: 8),
            _buildRailItem(
              index: 2,
              icon: Icons.info_outline,
              selectedIcon: Icons.info,
              label: 'About',
              activeColor: colors.f1RedBright,
              inactiveColor: colors.textMuted,
              textColor: onSurface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
    required Color textColor,
  }) {
    final selected = _index == index;
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Haptics.light();
          setState(() => _index = index);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.f1Red.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: selected ? activeColor : inactiveColor,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? textColor : inactiveColor,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = AppColors.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const barHeight = 35.0;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      child: Container(
        height: barHeight + bottomInset,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.surfaceAlt.withValues(alpha: 0.98),
              colors.surface.withValues(alpha: 0.98),
            ],
          ),
          border: Border(
            top: BorderSide(color: colors.border, width: isDark ? 0.5 : 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 14,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            height: barHeight + bottomInset,
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                  activeColor: colors.f1RedBright,
                  inactiveColor: colors.textMuted,
                  textColor: onSurface,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Widgets',
                  activeColor: colors.f1RedBright,
                  inactiveColor: colors.textMuted,
                  textColor: onSurface,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.info_outline,
                  selectedIcon: Icons.info,
                  label: 'About',
                  activeColor: colors.f1RedBright,
                  inactiveColor: colors.textMuted,
                  textColor: onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
    required Color textColor,
  }) {
    final selected = _index == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          Haptics.light();
          setState(() {
            _index = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: selected ? activeColor : inactiveColor,
              size: 28,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? textColor : inactiveColor,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Widgets';
      case 2:
        return 'About';
      case 0:
      default:
        return 'GridGlance';
    }
  }
}
