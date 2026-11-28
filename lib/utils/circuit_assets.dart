/// Circuit layout maps bundled in `lib/assets/circuits/`.
///
/// Callers look a circuit up here instead of building a path from the API's
/// `circuitId`: the API's ids don't always match the file names (`vegas` is
/// `las_vegas.svg`), and asking the asset bundle for a file that isn't there
/// raises an error even when the caller handles it.
class CircuitAssets {
  CircuitAssets._();

  /// Bundled map files, by name without `.svg`.
  static const Set<String> bundled = {
    'albert_park',
    'americas',
    'bahrain',
    'baku',
    'catalunya',
    'hungaroring',
    'imola',
    'interlagos',
    'jeddah',
    'las_vegas',
    'losail',
    'marina_bay',
    'miami',
    'monaco',
    'monza',
    'red_bull_ring',
    'rodriguez',
    'shanghai',
    'silverstone',
    'spa',
    'suzuka',
    'villeneuve',
    'yas_marina',
    'zandvoort',
  };

  /// API circuit ids whose map file has a different name.
  static const Map<String, String> _aliases = {'vegas': 'las_vegas'};

  /// Asset path of the map for [circuitId], or null when none is bundled.
  static String? pathFor(String circuitId) {
    final id = circuitId.trim();
    final name = _aliases[id] ?? id;
    return bundled.contains(name) ? 'lib/assets/circuits/$name.svg' : null;
  }
}
