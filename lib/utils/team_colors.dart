import 'package:flutter/material.dart';

/// Returns the official team colour for the given team name or constructor ID.
///
/// Falls back to a neutral grey if no match is found.
Color teamColor(String teamName) {
  final key = teamName.trim().toLowerCase();
  for (final entry in _teamColors.entries) {
    if (key.contains(entry.key)) {
      return entry.value;
    }
  }
  return const Color(0xFF9EA7B5); // neutral fallback
}

/// Returns a lighter tint of the team colour for gradients / backgrounds.
Color teamColorLight(String teamName) {
  return teamColor(teamName).withValues(alpha: 0.25);
}

// Ordered longest-key-first so greedy contains() matches the most specific name.
const Map<String, Color> _teamColors = {
  'oracle red bull racing': Color(0xFF3671C6),
  'red bull racing': Color(0xFF3671C6),
  'red bull': Color(0xFF3671C6),
  'scuderia ferrari': Color(0xFFE8002D),
  'ferrari': Color(0xFFE8002D),
  'mercedes-amg petronas': Color(0xFF27F4D2),
  'mercedes': Color(0xFF27F4D2),
  'mclaren': Color(0xFFFF8000),
  'aston martin': Color(0xFF229971),
  'alpine f1 team': Color(0xFFFF87BC),
  'alpine': Color(0xFFFF87BC),
  'williams': Color(0xFF64C4FF),
  'visa cash app rb': Color(0xFF6692FF),
  'racing bulls': Color(0xFF6692FF),
  'rb': Color(0xFF6692FF),
  'haas f1 team': Color(0xFFB6BABD),
  'haas': Color(0xFFB6BABD),
  'stake f1 team kick sauber': Color(0xFF52E252),
  'kick sauber': Color(0xFF52E252),
  'sauber': Color(0xFF52E252),
  'audi': Color(0xFF52E252),
  'cadillac': Color(0xFF1F4D2B),
};
