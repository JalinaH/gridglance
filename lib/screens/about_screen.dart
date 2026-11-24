import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const SizedBox(height: 8),

        // App icon and name
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.f1Red.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'GG',
                    style: TextStyle(
                      color: colors.f1Red,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'GridGlance',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              if (_version.isNotEmpty)
                Text(
                  'Version $_version',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              const SizedBox(height: 10),
              Text(
                'Your Formula 1 companion.\nStandings, schedules & results at a glance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Features section
        _buildSectionHeader(context, 'FEATURES'),
        const SizedBox(height: 10),
        _buildFeatureRow(
          context,
          Icons.emoji_events_outlined,
          'Live Standings',
          'Driver & constructor championships',
        ),
        _buildFeatureRow(
          context,
          Icons.calendar_month_outlined,
          'Race Calendar',
          'Full season schedule with session times',
        ),
        _buildFeatureRow(
          context,
          Icons.notifications_outlined,
          'Notifications',
          'Race reminders & result alerts',
        ),
        _buildFeatureRow(
          context,
          Icons.widgets_outlined,
          'Home Widgets',
          'Glanceable widgets for your home screen',
        ),
        _buildFeatureRow(
          context,
          Icons.cloud_outlined,
          'Race Weather',
          'Weekend forecasts for every circuit',
        ),
        _buildFeatureRow(
          context,
          Icons.share_outlined,
          'Share Cards',
          'Share beautiful race result cards',
        ),

        const SizedBox(height: 24),

        // Info section
        _buildSectionHeader(context, 'INFO'),
        const SizedBox(height: 10),
        _buildInfoCard(
          context,
          title: 'Data Source',
          value: 'Jolpica F1 API (Ergast)',
        ),
        _buildInfoCard(context, title: 'Weather Data', value: 'Open-Meteo'),
        const SizedBox(height: 24),

        // Links section
        _buildSectionHeader(context, 'LINKS'),
        const SizedBox(height: 10),
        _buildLinkTile(
          context,
          icon: Icons.star_outline,
          title: 'Rate on Play Store',
          onTap: () => _launchUrl(
            'https://play.google.com/store/apps/details?id=com.gridglance.app',
          ),
        ),
        _buildLinkTile(
          context,
          icon: Icons.language_outlined,
          title: 'Website',
          onTap: () => _launchUrl('https://jalinah.github.io/gridglance-web/'),
        ),
        _buildLinkTile(
          context,
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () => _launchUrl(
            'https://jalinah.github.io/gridglance-web/privacy.html',
          ),
        ),
        _buildLinkTile(
          context,
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: () =>
              _launchUrl('https://jalinah.github.io/gridglance-web/terms.html'),
        ),
        _buildLinkTile(
          context,
          icon: Icons.mail_outline,
          title: 'Send Feedback',
          onTap: () => _launchUrl('mailto:info.gridglance@gmail.com'),
        ),

        const SizedBox(height: 28),

        // Footer
        Center(
          child: Column(
            children: [
              Text(
                'Made with passion for F1 fans',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '\u00a9 ${DateTime.now().year} GridGlance',
                style: TextStyle(
                  color: colors.textMuted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: colors.f1Red,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.f1Red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colors.f1Red, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: colors.textMuted, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.f1Red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
