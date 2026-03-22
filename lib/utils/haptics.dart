import 'package:flutter/services.dart';

/// Lightweight wrapper around [HapticFeedback] for consistent tactile cues.
class Haptics {
  Haptics._();

  /// Card taps, filter chips, tab switches — light touch.
  static void light() => HapticFeedback.lightImpact();

  /// Toggling favorites, saving predictions — noticeable confirmation.
  static void medium() => HapticFeedback.mediumImpact();

  /// Selection ticks (e.g. ChoiceChip, Switch toggle).
  static void selection() => HapticFeedback.selectionClick();
}
