import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TeamLogo extends StatelessWidget {
  final String teamName;
  final double size;
  final BoxFit fit;

  const TeamLogo({
    super.key,
    required this.teamName,
    this.size = 28,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final asset = _logoAssetFor(teamName);
    if (asset == null) {
      return _fallback();
    }

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: fit,
    );
  }

  Widget _fallback() {
    final display = teamName.isNotEmpty
        ? teamName.trim().characters.first.toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      alignment: Alignment.center,
      child: Text(
        display,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String? _logoAssetFor(String teamName) {
    final normalized = _normalize(teamName);
    if (normalized.isEmpty) {
      return null;
    }
    final direct = _teamLogos[normalized];
    if (direct != null) {
      return direct;
    }

    String? fallback;
    int bestLength = 0;
    for (final entry in _teamLogos.entries) {
      if (normalized.contains(entry.key) && entry.key.length > bestLength) {
        bestLength = entry.key.length;
        fallback = entry.value;
      }
    }
    return fallback;
  }

  static String _normalize(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final isAlphaNum = (rune >= 97 && rune <= 122) ||
          (rune >= 48 && rune <= 57);
      if (isAlphaNum) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static const Map<String, String> _teamLogos = {
    'redbull': 'lib/assets/images/red-bull.png',
    'redbullracing': 'lib/assets/images/red-bull.png',
    'rb': 'lib/assets/images/rb.png',
    'racingbulls': 'lib/assets/images/rb.png',
    'vcarb': 'lib/assets/images/rb.png',
    'ferrari': 'lib/assets/images/ferrari.png',
    'scuderiaferrari': 'lib/assets/images/ferrari.png',
    'mercedes': 'lib/assets/images/mercedes.png',
    'mercedesamg': 'lib/assets/images/mercedes.png',
    'mercedesamgpetronas': 'lib/assets/images/mercedes.png',
    'mclaren': 'lib/assets/images/mclaren.png',
    'mclarenf1team': 'lib/assets/images/mclaren.png',
    'astonmartin': 'lib/assets/images/aston.png',
    'astonmartinf1team': 'lib/assets/images/aston.png',
    'alpine': 'lib/assets/images/alpine.png',
    'alpinef1team': 'lib/assets/images/alpine.png',
    'haas': 'lib/assets/images/haas.png',
    'haasf1team': 'lib/assets/images/haas.png',
    'williams': 'lib/assets/images/williams.png',
    'williamsracing': 'lib/assets/images/williams.png',
    'sauber': 'lib/assets/images/audi.png',
    'kicksauber': 'lib/assets/images/audi.png',
    'stakef1team': 'lib/assets/images/audi.png',
    'stakef1teamkicksauber': 'lib/assets/images/audi.png',
    'audi': 'lib/assets/images/audi.png',
    'cadillac': 'lib/assets/images/cadillac.png',
    'andretti': 'lib/assets/images/cadillac.png',
  };
}
