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
