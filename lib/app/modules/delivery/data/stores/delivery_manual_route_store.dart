import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DeliveryManualRoute {
  const DeliveryManualRoute({required this.name, required this.points});

  final String name;

  final List<List<double>> points;

  Map<String, Object?> toJson() => {
        'nombre': name,
        'puntos': points,
      };

  static DeliveryManualRoute? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['nombre']?.toString().trim() ?? '';
    final rawPoints = raw['puntos'];
    if (rawPoints is! List || rawPoints.isEmpty) return null;
    final points = <List<double>>[];
    for (final entry in rawPoints) {
      if (entry is! List || entry.length < 2) continue;
      final lng = double.tryParse('${entry[0]}');
      final lat = double.tryParse('${entry[1]}');
      if (lng == null || lat == null) continue;
      points.add([lng, lat]);
    }
    if (points.length < 2) return null;
    return DeliveryManualRoute(name: name.isEmpty ? 'Ruta' : name, points: points);
  }
}

class DeliveryManualRouteStore {
  DeliveryManualRouteStore._();

  static const _storageKey = 'delivery_rutas_manuales';

  static Future<List<DeliveryManualRoute>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(DeliveryManualRoute.fromJson)
          .whereType<DeliveryManualRoute>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<DeliveryManualRoute> routes) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      routes.map((route) => route.toJson()).toList(),
    );
    await prefs.setString(_storageKey, payload);
  }
}