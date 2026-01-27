import 'package:flutter/material.dart';

const Map<String, String> kTeamLogoAssets = {
  // 2026 teams (official list names)
  'mclaren': 'assets/teams/mclaren.png',
  'mercedes': 'assets/teams/mercedes.png',
  'red bull racing': 'assets/teams/red_bull.png',
  'ferrari': 'assets/teams/ferrari.png',
  'williams': 'assets/teams/williams.png',
  'racing bulls': 'assets/teams/rb.png',
  'aston martin': 'assets/teams/aston_martin.png',
  'haas f1 team': 'assets/teams/haas.png',
  'haas': 'assets/teams/haas.png',
  'audi': 'assets/teams/audi.png',
  'alpine': 'assets/teams/alpine.png',
  'cadillac': 'assets/teams/cadillac.png',

  // Common variations / legacy names (safe fallbacks)
  'red bull': 'assets/teams/red_bull.png',
  'oracle red bull racing': 'assets/teams/red_bull.png',
  'mclaren mercedes': 'assets/teams/mclaren.png',
  'mercedes-amg': 'assets/teams/mercedes.png',
  'mercedes-amg petronas': 'assets/teams/mercedes.png',
  'aston martin f1 team': 'assets/teams/aston_martin.png',
  'alpine f1 team': 'assets/teams/alpine.png',
  'rb': 'assets/teams/rb.png',
  'visa cash app rb': 'assets/teams/rb.png',
  'sauber': 'assets/teams/sauber.png',
  'kick sauber': 'assets/teams/sauber.png',
  'stake f1 team kick sauber': 'assets/teams/sauber.png',
};

String? teamLogoAsset(String teamName) {
  final key = teamName.trim().toLowerCase();
  return kTeamLogoAssets[key];
}

Widget teamLogoOrIcon(String teamName, {double size = 20}) {
  final asset = teamLogoAsset(teamName);
  if (asset == null) {
    return Icon(Icons.directions_car, size: size);
  }
  return Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => Icon(Icons.directions_car, size: size),
  );
}
