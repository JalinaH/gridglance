class JsonSafe {
  JsonSafe._();

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  static Map<String, dynamic>? asMapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static List<dynamic> asList(dynamic value) =>
      value is List ? value : const <dynamic>[];
}

/// Typed reader over a JSON object. Wraps a `Map<String, dynamic>` and
/// exposes accessors that coerce values rather than throwing on schema
/// drift, so model `fromJson` factories don't need ad-hoc `as` casts or
/// `?? ''` defaults at every call site.
class JsonReader {
  final Map<String, dynamic> _json;

  const JsonReader._(this._json);

  factory JsonReader(Map<String, dynamic> json) => JsonReader._(json);

  /// Wraps the nested object at [key]. Returns an empty reader if the key
  /// is missing or its value isn't a JSON object.
  JsonReader requireMap(String key) =>
      JsonReader._(JsonSafe.asMap(_json[key]));

  /// Wraps the nested object at [key], or null if missing / not an object.
  JsonReader? optMap(String key) {
    final map = JsonSafe.asMapOrNull(_json[key]);
    return map == null ? null : JsonReader._(map);
  }

  /// Returns the list at [key], or an empty list if missing / not a list.
  List<dynamic> requireList(String key) => JsonSafe.asList(_json[key]);

  /// Yields a [JsonReader] for each map-typed entry at [key], skipping
  /// non-object items.
  Iterable<JsonReader> readers(String key) sync* {
    for (final item in requireList(key)) {
      final map = JsonSafe.asMapOrNull(item);
      if (map != null) yield JsonReader._(map);
    }
  }

  /// Returns the string at [key], or null if missing.
  /// Non-string scalars are coerced via `toString()`.
  String? optString(String key) {
    final v = _json[key];
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  /// Returns the string at [key], falling back to [defaultValue] if absent.
  String string(String key, {String defaultValue = ''}) =>
      optString(key) ?? defaultValue;

  /// Returns the int at [key], parsing strings if needed.
  int? optInt(String key) {
    final v = _json[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Returns the double at [key], parsing strings if needed.
  double? optDouble(String key) {
    final v = _json[key];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
