import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryManualRoute {
  const DeliveryManualRoute({required this.name, required this.points});

  final String name;

  final List<List<double>> points;

  Map<String, Object?> toJson() => {'nombre': name, 'puntos': points};

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
      if (!lng.isFinite || !lat.isFinite) continue;
      points.add([lng, lat]);
    }
    if (points.length < 2) return null;
    return DeliveryManualRoute(
      name: name.isEmpty ? 'Ruta' : name,
      points: points,
    );
  }
}

class DeliveryManualRouteStore {
  DeliveryManualRouteStore._();

  static const _storageKey = 'delivery_rutas_manuales';
  static const _fileName = 'delivery_rutas_manuales.json';

  static List<DeliveryManualRoute> _parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <DeliveryManualRoute>[];
      return decoded
          .map(DeliveryManualRoute.fromJson)
          .whereType<DeliveryManualRoute>()
          .toList();
    } catch (error) {
      debugPrint('DeliveryManualRouteStore: no se pudo leer el dato: $error');
      return <DeliveryManualRoute>[];
    }
  }

  static Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (error) {
      debugPrint(
        'DeliveryManualRouteStore: sin directorio de documentos: $error',
      );
      return null;
    }
  }

  /// Devuelve siempre una lista **modificable**: las pantallas agregan la ruta nueva
  /// con `routes.add(...)` sobre el resultado de este metodo.
  static Future<List<DeliveryManualRoute>> load() async {
    final file = await _file();
    if (file != null && await file.exists()) {
      try {
        final text = await file.readAsString();
        final routes = _parse(text);
        if (routes.isNotEmpty) return routes;
      } catch (error) {
        debugPrint(
          'DeliveryManualRouteStore: fallo leyendo el archivo: $error',
        );
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return <DeliveryManualRoute>[];
      return _parse(raw).toList();
    } catch (error) {
      debugPrint(
        'DeliveryManualRouteStore: fallo leyendo preferencias: $error',
      );
      return <DeliveryManualRoute>[];
    }
  }

  static Future<bool> save(List<DeliveryManualRoute> routes) async {
    final payload = jsonEncode(routes.map((route) => route.toJson()).toList());
    var written = false;

    final file = await _file();
    if (file != null) {
      try {
        await file.writeAsString(payload, flush: true);
        written = true;
      } catch (error) {
        debugPrint(
          'DeliveryManualRouteStore: fallo escribiendo el archivo: $error',
        );
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsOk = await prefs.setString(_storageKey, payload);
      written = written || prefsOk;
    } catch (error) {
      debugPrint(
        'DeliveryManualRouteStore: fallo escribiendo preferencias: $error',
      );
    }

    if (!written) return false;

    final stored = await load();
    final persisted =
        stored.length >= routes.length &&
        routes.every(
          (route) => stored.any(
            (item) =>
                item.name == route.name &&
                item.points.length == route.points.length,
          ),
        );
    debugPrint(
      'DeliveryManualRouteStore: guardadas ${routes.length}, leidas ${stored.length}, verificado=$persisted',
    );
    return persisted;
  }
}
