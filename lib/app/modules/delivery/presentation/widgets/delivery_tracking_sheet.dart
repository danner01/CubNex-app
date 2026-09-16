import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import 'delivery_common.dart';

Future<void> showDeliveryTrackingSheet(BuildContext context, String ordenId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DeliveryTrackingSheet(ordenId: ordenId),
  );
}

class DeliveryTrackingSheet extends StatefulWidget {
  const DeliveryTrackingSheet({required this.ordenId, super.key});

  final String ordenId;

  @override
  State<DeliveryTrackingSheet> createState() => _DeliveryTrackingSheetState();
}

class _DeliveryTrackingSheetState extends State<DeliveryTrackingSheet> {
  static const _pollInterval = Duration(seconds: 8);
  final ApiClient _apiClient = sl<ApiClient>();

  String? _entregaId;
  Map<String, dynamic> _ubicacion = const {};
  bool _entregaLoading = true;
  bool _hasEntrega = false;
  Timer? _pollTimer;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  String? _renderedKey;
  Color? _markerColor;
  String? _deliveryAvatarUrl;
  String? _deliveryTipoVehiculo;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
    unawaited(_resolveEntrega());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveEntrega() async {
    final result = await _apiClient.get<List<Map<String, dynamic>>>(
      '/entregas',
      queryParameters: {
        'orden_id': 'eq.${widget.ordenId}',
        'select': 'id,estado',
      },
      parser: (json) {
        if (json is List) {
          return json.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
        return const [];
      },
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        _entregaLoading = false;
        _hasEntrega = false;
      });
      return;
    }
    final items = result.data ?? const <Map<String, dynamic>>[];
    final first = items.isEmpty ? null : items.first;
    if (first == null) {
      setState(() {
        _entregaLoading = false;
        _hasEntrega = false;
      });
      return;
    }
    setState(() {
      _entregaId = '${first['id']}';
      _entregaLoading = false;
      _hasEntrega = true;
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    final entregaId = _entregaId;
    if (entregaId == null || !_hasEntrega) return;
    final result = await _apiClient.get<Map<String, dynamic>?>(
      '/entregas/$entregaId/ubicacion-reciente',
      parser: (json) {
        if (json is Map) return Map<String, dynamic>.from(json);
        return null;
      },
    );
    if (!mounted || !result.isSuccess) return;
    setState(() {
      _ubicacion = result.data ?? const {};
      final delivery = _ubicacion['delivery'];
      final deliveryMap = delivery is Map
          ? Map<String, dynamic>.from(delivery)
          : const <String, dynamic>{};
      final hex = deliveryMap['color_marcador'];
      _markerColor =
          parseDeliveryMarkerColor(hex) ??
          parseDeliveryMarkerColor(deliveryDefaultMarkerColor);
      _deliveryAvatarUrl = deliveryMap['avatar_url']?.toString();
      _deliveryTipoVehiculo = deliveryMap['tipo_vehiculo']?.toString();
    });
    await _syncMarker();
  }

  Future<void> _syncMarker() async {
    final point = _coords(_ubicacion['coordenadas']);
    if (point == null) return;
    final key = point.join(',');
    if (key == _renderedKey) return;
    _renderedKey = key;
    final manager = _pointManager;
    if (manager == null) return;
    await manager.deleteAll();
    await manager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(point[0], point[1])),
        iconImage: 'marker',
        iconColor: (_markerColor ?? Colors.blue).toARGB32(),
        iconSize: 1.3,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(point[0], point[1])),
        zoom: 14,
      ),
      MapAnimationOptions(duration: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = _coords(_ubicacion['coordenadas']);
    final updated = DateTime.tryParse('${_ubicacion['created_at'] ?? ''}');
    final speed = _num(_ubicacion['velocidad_kmh']);
    final accuracy = _num(_ubicacion['precision_metros']);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_hasEntrega) ...[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: (_markerColor ?? Colors.blue).withValues(
                      alpha: 0.85,
                    ),
                    backgroundImage: _deliveryAvatarUrl?.isNotEmpty == true
                        ? NetworkImage(_deliveryAvatarUrl!)
                        : null,
                    child: _deliveryAvatarUrl?.isNotEmpty == true
                        ? null
                        : Icon(
                            deliveryVehicleIcon(_deliveryTipoVehiculo),
                            color: readableDeliveryMarkerIconColor(
                              _markerColor ?? Colors.blue,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seguimiento del repartidor',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hasEntrega
                            ? 'Ubicacion en tiempo real del repartidor asignado.'
                            : 'Este pedido no tiene un repartidor asignado todavia.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_entregaLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_hasEntrega)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Cuando un repartidor acepte la entrega podras seguir su '
                  'ubicacion desde aqui.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: point == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: const Center(
                            child: Text(
                              'El repartidor aun no reporta ubicacion.',
                            ),
                          ),
                        )
                      : MapWidget(
                          // ignore: deprecated_member_use
                          cameraOptions: CameraOptions(
                            center: Point(
                              coordinates: Position(point[0], point[1]),
                            ),
                            zoom: 14,
                          ),
                          onMapCreated: _onMapCreated,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (speed != null)
                    _chip(
                      theme,
                      Icons.speed_rounded,
                      '${speed.toStringAsFixed(0)} km/h',
                    ),
                  if (accuracy != null)
                    _chip(
                      theme,
                      Icons.gps_fixed_rounded,
                      'Precision ${accuracy.toStringAsFixed(0)} m',
                    ),
                  if (updated != null)
                    _chip(
                      theme,
                      Icons.schedule_rounded,
                      'Actualizado ${_clock(updated)}',
                    ),
                ],
              ),
              if (updated != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ultima senal: ${updated.day.toString().padLeft(2, '0')}/${updated.month.toString().padLeft(2, '0')}/${updated.year} ${_clock(updated)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _pointManager?.setIconAllowOverlap(true);
    await _syncMarker();
  }

  Widget _chip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<double>? _coords(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final lat = _num(map['lat']) ?? _num(map['latitude']) ?? _num(map['y']);
    final lng =
        _num(map['lng']) ??
        _num(map['lon']) ??
        _num(map['longitude']) ??
        _num(map['x']);
    if (lat == null || lng == null) return null;
    return [lng, lat];
  }

  double? _num(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String _clock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
