import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

import '../../config/http/api_client.dart';

class ProximityAlert {
  const ProximityAlert({
    required this.key,
    required this.title,
    required this.body,
    required this.lat,
    required this.lng,
    this.businessId,
    this.connectPath,
    this.isOpportunity = false,
  });

  final String key;
  final String title;
  final String body;
  final double lat;
  final double lng;
  final String? businessId;
  final String? connectPath;
  final bool isOpportunity;
}

/// Avisa (mientras la app esta abierta) cuando el usuario pasa cerca de un
/// negocio con productos de su interes o con oportunidades para su negocio.
/// Solo corre si el usuario activo las notificaciones cercanas.
class ProximityAlertService {
  ProximityAlertService._();
  static final instance = ProximityAlertService._();

  static const _boxName = 'proximity_seen';
  static const _cooldown = Duration(hours: 12);
  static const _minCheckGap = Duration(minutes: 2);

  final ValueNotifier<ProximityAlert?> current = ValueNotifier(null);
  final List<ProximityAlert> _queue = [];
  StreamSubscription<Position>? _sub;
  DateTime? _lastCheck;
  ApiClient? _api;
  bool _checking = false;

  bool get running => _sub != null;

  Future<void> start(ApiClient api) async {
    if (running) return;
    _api = api;
    final prefs = await api.get<Map<String, dynamic>>(
      '/usuarios/preferencias/oportunidades',
      parser: (j) => Map<String, dynamic>.from(j as Map),
    );
    if (!prefs.isSuccess ||
        prefs.data?['notificaciones_cercanas_opt_in'] != true) {
      return;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 120,
        ),
      ).listen(_onPosition, onError: (_) {});
    } on Object {
      // Sin permiso o sin GPS: no se avisa.
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _queue.clear();
    current.value = null;
  }

  void dismiss() {
    current.value = _queue.isEmpty ? null : _queue.removeAt(0);
  }

  Future<void> _onPosition(Position p) async {
    final api = _api;
    if (api == null || _checking) return;
    final now = DateTime.now();
    if (_lastCheck != null && now.difference(_lastCheck!) < _minCheckGap) {
      return;
    }
    _checking = true;
    _lastCheck = now;
    try {
      final res = await api.get<Map<String, dynamic>>(
        '/proximidad/alertas',
        queryParameters: {
          'lat': p.latitude,
          'lng': p.longitude,
          'radio_km': 1,
        },
        parser: (j) => Map<String, dynamic>.from(j as Map),
      );
      if (res.error?.statusCode == 401) {
        await stop();
        return;
      }
      if (!res.isSuccess) return;
      await _ingest(res.data!);
    } finally {
      _checking = false;
    }
  }

  Future<void> _ingest(Map<String, dynamic> data) async {
    final box = await Hive.openBox<int>(_boxName);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fresh = <ProximityAlert>[];

    bool isNew(String key) {
      final last = box.get(key);
      return last == null || nowMs - last > _cooldown.inMilliseconds;
    }

    String km(dynamic d) {
      final v = (d as num?)?.toDouble() ?? 0;
      return v < 1 ? '${(v * 1000).round()} m' : '${v.toStringAsFixed(1)} km';
    }

    for (final raw in (data['productos'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(raw as Map);
      final key = 'p:${m['producto_id']}:${m['negocio_id']}';
      if (!isNew(key)) continue;
      fresh.add(
        ProximityAlert(
          key: key,
          title: '${m['nombre']} cerca de ti',
          body:
              '${m['negocio']} (${km(m['distancia_km'])}) · ${m['precio']} ${m['moneda']}',
          lat: (m['lat'] as num).toDouble(),
          lng: (m['lng'] as num).toDouble(),
          businessId: '${m['negocio_id']}',
        ),
      );
    }
    for (final raw in (data['negocios_favoritos'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(raw as Map);
      final key = 'f:${m['negocio_id']}';
      if (!isNew(key)) continue;
      fresh.add(
        ProximityAlert(
          key: key,
          title: 'Tu negocio favorito esta cerca',
          body: '${m['nombre']} (${km(m['distancia_km'])})',
          lat: (m['lat'] as num).toDouble(),
          lng: (m['lng'] as num).toDouble(),
          businessId: '${m['negocio_id']}',
        ),
      );
    }
    for (final raw in (data['oportunidades'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(raw as Map);
      final key = 'o:${m['negocio_id']}';
      if (!isNew(key)) continue;
      fresh.add(
        ProximityAlert(
          key: key,
          title: m['tipo'] == 'alianza'
              ? 'Posible alianza cerca: ${m['nombre']}'
              : 'Oportunidad cerca: ${m['nombre']}',
          body: '${m['motivo']}',
          lat: (m['lat'] as num).toDouble(),
          lng: (m['lng'] as num).toDouble(),
          businessId: '${m['negocio_id']}',
          connectPath: m['conectar_path'] as String?,
          isOpportunity: true,
        ),
      );
    }

    // Maximo 3 avisos por revision para no saturar.
    for (final alert in fresh.take(3)) {
      await box.put(alert.key, nowMs);
      _queue.add(alert);
    }
    if (current.value == null && _queue.isNotEmpty) {
      current.value = _queue.removeAt(0);
    }
  }
}
