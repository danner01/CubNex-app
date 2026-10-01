import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../widgets/delivery_common.dart';

class DeliveryOrderTrackingScreen extends StatefulWidget {
  const DeliveryOrderTrackingScreen({
    required this.ordenId,
    this.entregaId,
    super.key,
  });

  final String ordenId;

  /// Id de la entrega cuando el llamador ya la conoce, para evitar re-buscar
  /// por orden (que depende del scope del rol).
  final String? entregaId;

  @override
  State<DeliveryOrderTrackingScreen> createState() =>
      _DeliveryOrderTrackingScreenState();
}

class _DeliveryOrderTrackingScreenState
    extends State<DeliveryOrderTrackingScreen> {
  static const _pollInterval = Duration(seconds: 8);
  static final _defaultCenter = Position(-82.3666, 23.1136);

  final ApiClient _apiClient = sl<ApiClient>();

  bool _entregaLoading = true;
  bool _hasEntrega = false;
  String? _entregaId;
  DeliveryEntregaModel? _entrega;

  Map<String, dynamic> _ubicacion = const {};
  Timer? _pollTimer;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _routeManager;
  Color? _markerColor;
  String? _deliveryAvatarUrl;
  String? _deliveryTipoVehiculo;

  String? _lastDeliveryKey;
  bool _didInitialCamera = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_hasEntrega ? _refresh() : _resolveEntrega()),
    );
    unawaited(_resolveEntrega());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveEntrega() async {
    final knownEntregaId = widget.entregaId;
    if (knownEntregaId != null && knownEntregaId.isNotEmpty) {
      setState(() {
        _entregaId = knownEntregaId;
        _entregaLoading = false;
        _hasEntrega = true;
      });
      await Future.wait([
        _loadDetalle(knownEntregaId),
        _refresh(),
      ]);
      return;
    }

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
    await Future.wait([
      _loadDetalle('${first['id']}'),
      _refresh(),
    ]);
  }

  Future<void> _loadDetalle(String entregaId) async {
    final result = await _apiClient.get<DeliveryEntregaModel?>(
      '/entregas/$entregaId',
      parser: (json) {
        if (json is! Map) return null;
        return DeliveryEntregaModel.fromJson(Map<String, dynamic>.from(json));
      },
    );
    if (!mounted || !result.isSuccess) return;
    setState(() => _entrega = result.data);
    await _syncPoints();
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
    await _syncPoints();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _pointManager?.setIconAllowOverlap(true);
    _pointManager?.setTextAllowOverlap(true);
    _routeManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    await _syncPoints();
  }

  Future<void> _syncPoints() async {
    final map = _mapboxMap;
    final pointManager = _pointManager;
    final routeManager = _routeManager;
    if (map == null || pointManager == null || routeManager == null) return;

    final entrega = _entrega;
    final origin = entrega == null ? null : _origin(entrega);
    final dest = entrega == null ? null : _dest(entrega);
    final delivery = _coords(_ubicacion['coordenadas']);

    try {
      await routeManager.deleteAll();
      final routeCoords = entrega?.rutaCoordenadas;
      final drawLine = (routeCoords != null && routeCoords.length >= 2)
          ? routeCoords
          : (origin != null && dest != null ? [origin, dest] : null);
      if (drawLine != null) {
        await routeManager.create(
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: [
                for (final point in drawLine) Position(point[0], point[1]),
              ],
            ),
            lineColor: DeliveryRouteColors.route.toARGB32(),
            lineWidth: 5.5,
            lineOpacity: 0.85,
            lineBorderColor: Colors.white.toARGB32(),
            lineBorderWidth: 1.4,
          ),
        );
      }

      await pointManager.deleteAll();

      if (origin != null) {
        final icon = await ensureDeliveryPinIcon(
          map,
          DeliveryRouteColors.origin,
          keyPrefix: 'del_track_origin',
        );
        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(origin[0], origin[1])),
            iconImage: icon,
            iconColor: icon == null ? DeliveryRouteColors.origin.toARGB32() : null,
            iconSize: 1.0,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      }
      if (dest != null) {
        final icon = await ensureDeliveryPinIcon(
          map,
          DeliveryRouteColors.destination,
          keyPrefix: 'del_track_dest',
        );
        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(dest[0], dest[1])),
            iconImage: icon,
            iconColor:
                icon == null ? DeliveryRouteColors.destination.toARGB32() : null,
            iconSize: 1.0,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      }
      if (delivery != null) {
        final color = _markerColor ?? DeliveryRouteColors.delivery;
        final icon = await ensureDeliveryMarkerIcon(
          map,
          color,
          _deliveryTipoVehiculo,
        );
        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(delivery[0], delivery[1])),
            iconImage: icon ?? 'marker',
            iconColor: icon == null ? color.toARGB32() : null,
            iconSize: 1.25,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      }
    } catch (error) {
      debugPrint('OrderTracking: no se pudo pintar el mapa: $error');
    }

    await _maybeCamera();
  }

  Future<void> _maybeCamera() async {
    final map = _mapboxMap;
    if (map == null) return;
    final entrega = _entrega;
    final origin = entrega == null ? null : _origin(entrega);
    final dest = entrega == null ? null : _dest(entrega);
    final delivery = _coords(_ubicacion['coordenadas']);

    final points = <List<double>>[];
    if (origin != null) points.add(origin);
    if (dest != null) points.add(dest);
    if (delivery != null) points.add(delivery);
    if (points.isEmpty) return;

    if (delivery != null) {
      final key = delivery.join(',');
      final changed = key != _lastDeliveryKey;
      _lastDeliveryKey = key;
      if (!_didInitialCamera) {
        _didInitialCamera = true;
        await _fitPoints(points);
      } else if (changed) {
        await _flyToDelivery(delivery);
      }
    } else if (!_didInitialCamera) {
      _didInitialCamera = true;
      await _fitPoints(points);
    }
  }

  Future<void> _fitPoints(List<List<double>> points) async {
    final map = _mapboxMap;
    if (map == null || points.isEmpty) return;
    final center = _bboxCenter(points);
    if (center == null) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(center[0], center[1])),
        zoom: _zoomFor(points),
      ),
      MapAnimationOptions(duration: 450),
    );
  }

  Future<void> _flyToDelivery(List<double> point) async {
    final map = _mapboxMap;
    if (map == null) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(point[0], point[1])),
        zoom: 14.5,
      ),
      MapAnimationOptions(duration: 350),
    );
  }

  List<double>? _origin(DeliveryEntregaModel entrega) {
    final lng = entrega.negocioLongitude;
    final lat = entrega.negocioLatitude;
    if (lng == null || lat == null) return null;
    return [lng, lat];
  }

  List<double>? _dest(DeliveryEntregaModel entrega) {
    final lng = entrega.destinoLongitude;
    final lat = entrega.destinoLatitude;
    if (lng == null || lat == null) return null;
    return [lng, lat];
  }

  List<double>? _bboxCenter(List<List<double>> coords) {
    if (coords.isEmpty) return null;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    for (final point in coords) {
      final lng = point[0];
      final lat = point[1];
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }
    if (minLng > maxLng || minLat > maxLat) return null;
    return [(minLng + maxLng) / 2, (minLat + maxLat) / 2];
  }

  double _zoomFor(List<List<double>> coords) {
    if (coords.isEmpty) return 13;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    for (final point in coords) {
      minLng = point[0] < minLng ? point[0] : minLng;
      maxLng = point[0] > maxLng ? point[0] : maxLng;
      minLat = point[1] < minLat ? point[1] : minLat;
      maxLat = point[1] > maxLat ? point[1] : maxLat;
    }
    final lngSpan = maxLng - minLng;
    final latSpan = maxLat - minLat;
    final span = lngSpan > latSpan ? lngSpan : latSpan;
    if (span <= 0.01) return 14.5;
    if (span <= 0.05) return 13.2;
    if (span <= 0.2) return 12;
    return 10.5;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = _coords(_ubicacion['coordenadas']);
    final updated = DateTime.tryParse('${_ubicacion['created_at'] ?? ''}');
    final speed = _num(_ubicacion['velocidad_kmh']);
    final accuracy = _num(_ubicacion['precision_metros']);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              // ignore: deprecated_member_use
              cameraOptions: CameraOptions(
                center: Point(coordinates: _defaultCenter),
                zoom: 11,
              ),
              onMapCreated: _onMapCreated,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Volver',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.92,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: point != null
                                    ? Colors.green
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Seguimiento del pedido',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _buildBottomPanel(
                theme,
                point,
                updated,
                speed,
                accuracy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(
    ThemeData theme,
    List<double>? point,
    DateTime? updated,
    double? speed,
    double? accuracy,
  ) {
    final entrega = _entrega;
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      elevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_entregaLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_hasEntrega)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Este pedido no tiene un repartidor asignado todavia. '
                  'Cuando uno acepte la entrega podras seguir su ubicacion '
                  'en el mapa desde aqui.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              if (entrega != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _stopColumn(
                        theme,
                        icon: Icons.storefront_rounded,
                        color: DeliveryRouteColors.origin,
                        title: entrega.negocioNombre ?? 'Negocio',
                        subtitle: entrega.negocioDireccion ?? '',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Expanded(
                      child: _stopColumn(
                        theme,
                        icon: Icons.location_on_rounded,
                        color: DeliveryRouteColors.destination,
                        title: entrega.clienteNombre ?? 'Destino',
                        subtitle: entrega.clienteDireccionEntrega ?? '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (point != null) ...[
                    CircleAvatar(
                      radius: 20,
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Repartidor en ruta',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Sigue su movimiento en tiempo real aqui abajo.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Centrar en el repartidor',
                      onPressed: () => _flyToDelivery(point),
                      icon: const Icon(Icons.my_location_rounded),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'El repartidor aun no reporta ubicacion.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
              if (point != null && (speed != null || accuracy != null || updated != null)) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (speed != null)
                      _chip(theme, Icons.speed_rounded, '${speed.toStringAsFixed(0)} km/h'),
                    if (accuracy != null)
                      _chip(theme, Icons.gps_fixed_rounded, 'Precision ${accuracy.toStringAsFixed(0)} m'),
                    if (updated != null)
                      _chip(theme, Icons.schedule_rounded, 'Actualizado ${_clock(updated)}'),
                  ],
                ),
              ],
              if (point != null && updated != null) ...[
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

  Widget _stopColumn(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
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