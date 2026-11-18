import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache local de respuestas JSON para mostrar contenido al instante y
/// refrescarlo despues (util con conexion lenta o intermitente).
class JsonCache {
  JsonCache._();

  static const _prefix = 'json_cache_v1:';
  static const _maxChars = 200000;

  static Future<void> save(String key, dynamic json) async {
    try {
      final encoded = jsonEncode(json);
      if (encoded.length > _maxChars) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', encoded);
    } catch (_) {}
  }

  static Future<dynamic> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
