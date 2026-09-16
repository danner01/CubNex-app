import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/environment/app_environment.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/delivery/delivery_accepted_store.dart';
import '../../data/models/delivery_activo_model.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../widgets/delivery_common.dart';

class DeliveryRouteScreen extends StatefulWidget {
  const DeliveryRouteScreen({super.key});

  @override
  State<DeliveryRouteScreen> createState() => _DeliveryRouteScreenState();
}

class _DeliveryRouteScreenState extends State<DeliveryRouteScreen> {
  static const _pollInterval = Duration(seconds: 15);
  static final _defaultCenter = Position(-82.3666, 23.1136);
  static const _palette = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF3949AB),
  ];
  static const _myMarkerColor = Color(0xFF00ACC1);

  final ApiClient _apiClient = sl<ApiClient>();

  final List<DeliveryActivoModel> _items = [];
  Timer? _pollTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;
  double? _myLat;
  double? _myLng;
  bool _didInitialCamera = false;
  late final bool _tokenReady;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _routeManager;

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
    unawaited(_boot());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    final position = await _currentPosition();
    if (!mounted) return;
    setState(() {
      _myLat = position?.latitude;
      _myLng = position?.longitude;
    });
    await _refresh();
  }

  Future<geo.Position?> _currentPosition() async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return null;
    }
    return geo.Geolocator.getCurrentPosition();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final query = <String, dynamic>{'radio_km': '10'};
      if (_myLat != null && _myLng != null) {
        query['lat'] = '$_myLat';
        query['lng'] = '$_myLng';
      }
      final result = await _apiClient.get<List<DeliveryActivoModel>>(
        '/delivery-activos',
        queryParameters: query,
        parser: (json) {
          if (json is! List) return const <DeliveryActivoModel>[];
          return json
              .whereType<Map>()
              .map(
                (item) => DeliveryActivoModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        },
      );
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() {
          _items
            ..clear()
            ..addAll(result.data ?? const <DeliveryActivoModel>[]);
          _loading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _loading = false;
          _errorMessage =
              result.error?.message ??
              'No se pudieron cargar los repartidores.';
        });
      }
      await _syncAll(initial: !_didInitialCamera);
    } finally {
      _refreshing = false;
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _routeManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _pointManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    _pointManager?.setIconAllowOverlap(true);
    _pointManager?.setTextAllowOverlap(true);
    await _syncAll(initial: true);
  }

  Future<void> _syncAll({required bool initial}) async {
    final pointManager = _pointManager;
    if (pointManager == null) return;
    await _routeManager?.deleteAll();
    await pointManager.deleteAll();

    var hasAnyMarker = false;
    var minLat = double.infinity, maxLat = double.negativeInfinity;
    var minLng = double.infinity, maxLng = double.negativeInfinity;

    void track(double lat, double lng) {
      hasAnyMarker = true;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    if (_myLat != null && _myLng != null) {
      track(_myLat!, _myLng!);
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(_myLng!, _myLat!)),
          iconImage: 'marker',
          iconColor: _myMarkerColor.toARGB32(),
          iconSize: 1.45,
          iconAnchor: IconAnchor.BOTTOM,
          textField: 'Tu',
          textColor: const Color(0xFF006064).toARGB32(),
          textSize: 12,
        ),
      );
    }

    final items = List<DeliveryActivoModel>.from(_items);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final lat = item.ultimaUbicacion?.lat;
      final lng = item.ultimaUbicacion?.lng;
      if (lat == null || lng == null) continue;
      track(lat, lng);
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconImage: 'marker',
          iconColor: _markerColor(item, i).toARGB32(),
          iconSize: 1.15,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    final entrega = sl<DeliveryAcceptedStore>().accepted.value;
    if (entrega != null) {
      final route = entrega.rutaCoordenadas;
      if (route != null && route.length >= 2) {
        await _routeManager?.create(
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: route
                  .map((point) => Position(point[0], point[1]))
                  .toList(),
            ),
            lineColor: Colors.blue.toARGB32(),
            lineBorderColor: Colors.white.toARGB32(),
            lineBorderWidth: 1.4,
            lineWidth: 5.5,
            lineOpacity: 0.92,
          ),
        );
        await _addMarker(route.first, AppColorsForRoute.origin);
        await _addMarker(route.last, AppColorsForRoute.destination);
        track(route.first[1], route.first[0]);
        track(route.last[1], route.last[0]);
      } else if (route != null && route.isNotEmpty) {
        await _addMarker(route.first, AppColorsForRoute.origin);
        track(route.first[1], route.first[0]);
      } else if (entrega.negocioLongitude != null &&
          entrega.negocioLatitude != null) {
        await _addMarker([
          entrega.negocioLongitude!,
          entrega.negocioLatitude!,
        ], AppColorsForRoute.origin);
        track(entrega.negocioLatitude!, entrega.negocioLongitude!);
      }
    }

    if (!initial || _didInitialCamera) return;
    _didInitialCamera = true;

    if (entrega != null && entrega.rutaCoordenadas != null) {
      final routeCoords = entrega.rutaCoordenadas!;
      if (routeCoords.length >= 2) {
        final center = _bboxCenter(routeCoords);
        if (center != null) {
          await _mapboxMap?.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(center[0], center[1])),
              zoom: _zoomFor(routeCoords),
            ),
            MapAnimationOptions(duration: 400),
          );
          return;
        }
      }
    }

    if (_myLat != null && _myLng != null) {
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_myLng!, _myLat!)),
          zoom: 13,
        ),
        MapAnimationOptions(duration: 400),
      );
      return;
    }

    if (hasAnyMarker && !minLng.isInfinite) {
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position((minLng + maxLng) / 2, (minLat + maxLat) / 2),
          ),
          zoom: 12,
        ),
        MapAnimationOptions(duration: 400),
      );
      return;
    }

    await _mapboxMap?.flyTo(
      CameraOptions(center: Point(coordinates: _defaultCenter), zoom: 12),
      MapAnimationOptions(duration: 400),
    );
  }

  Future<void> _addMarker(List<double> point, Color color) async {
    final manager = _pointManager;
    if (manager == null) return;
    await manager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(point[0], point[1])),
        iconImage: 'marker',
        iconColor: color.toARGB32(),
        iconSize: 1.3,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
  }

  Color _markerColor(DeliveryActivoModel item, int index) {
    final custom = parseDeliveryMarkerColor(item.colorMarcador);
    if (custom != null) return custom;
    return _palette[index % _palette.length];
  }

  List<double>? _bboxCenter(List<List<double>> coords) {
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
    if (minLng > maxLng || minLat > maxLat) return null;
    return [(minLng + maxLng) / 2, (minLat + maxLat) / 2];
  }

  double _zoomFor(List<List<double>> coords) {
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

    return Scaffold(
      body: ValueListenableBuilder<DeliveryEntregaModel?>(
        valueListenable: sl<DeliveryAcceptedStore>().accepted,
        builder: (context, entrega, _) {
          final hasRouteOverlay = entrega != null;
          final routeInfoAvailable = hasRouteOverlay &&
              ((entrega.rutaCoordenadas?.isNotEmpty ?? false) ||
                  (entrega.negocioLongitude != null &&
                      entrega.negocioLatitude != null));
          final mapCenter = _myLat != null && _myLng != null
              ? Point(coordinates: Position(_myLng!, _myLat!))
              : Point(coordinates: _defaultCenter);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Ruta y mapa',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasRouteOverlay
                    ? 'Entrega aceptada y ruta hacia el cliente.'
                    : 'Mapa en tiempo real con tu posicion y los repartidores activos.',
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 340,
                  child: MapWidget(
                    // ignore: deprecated_member_use
                    cameraOptions: CameraOptions(
                      center: mapCenter,
                      zoom: 12,
                    ),
                    onMapCreated: _onMapCreated,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _MapLegendRow(showRoute: hasRouteOverlay),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _items.isEmpty
                          ? 'Repartidores activos'
                          : '${_items.length} repartidores activos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => unawaited(_refresh()),
                    tooltip: 'Actualizar',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _myLat == null
                    ? 'Sin ubicacion del dispositivo. Se muestran los repartidores por su posicion guardada.'
                    : 'Los repartidores actualizan su posicion cada pocos segundos.',
                style: theme.textTheme.bodySmall,
              ),
              if (_errorMessage != null && _items.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (routeInfoAvailable)
                ...[
                  _RouteSummaryCard(entrega: entrega),
                  const SizedBox(height: 14),
                ],
              if (_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty)
                _MessageCard(
                  message:
                      _errorMessage ??
                      (hasRouteOverlay
                          ? 'No hay otros repartidores activos ahora mismo.'
                          : 'No hay repartidores activos ahora mismo. El mapa muestra tu posicion en tiempo real.'),
                  onRetry: () => unawaited(_refresh()),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _ActiveDeliveryCard(item: _items[index]),
                ),
            ],
          );
        },
      ),
    );
  }

  }

class _MapLegendRow extends StatelessWidget {
  const _MapLegendRow({required this.showRoute});

  final bool showRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[
      _legendItem(
        theme,
        const Color(0xFF00ACC1),
        'Tu',
        labelColor: const Color(0xFF006064),
      ),
      _legendItem(theme, const Color(0xFF3949AB), 'Repartidor'),
      if (showRoute) ...[
        _legendItem(theme, AppColorsForRoute.origin, 'Origen'),
        _legendItem(theme, AppColorsForRoute.destination, 'Destino'),
        _legendItem(theme, Colors.blue, 'Ruta', line: true),
      ],
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  items[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(
    ThemeData theme,
    Color color,
    String label, {
    Color? labelColor,
    bool line = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (line)
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.item});

  final DeliveryActivoModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = item.distanciaKm.toStringAsFixed(1);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.16),
          backgroundImage: item.avatarUrl?.isNotEmpty == true
              ? NetworkImage(item.avatarUrl!)
              : null,
          child: item.avatarUrl?.isNotEmpty == true
              ? null
              : Icon(_vehiculoIcon(item.tipoVehiculo),
                  color: theme.colorScheme.secondary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.nombre ?? 'Repartidor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$distance km',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            _vehiculoLabel(item.tipoVehiculo),
            if (item.placa != null && item.placa!.isNotEmpty) item.placa,
            'Disponible',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: _ActiveDot(color: _markerColor(item)),
      ),
    );
  }

  Color _markerColor(DeliveryActivoModel item) {
    return parseDeliveryMarkerColor(item.colorMarcador) ??
        const Color(0xFF3949AB);
  }

  IconData _vehiculoIcon(String? vehiculo) {
    return switch (vehiculo) {
      'bicicleta' => Icons.pedal_bike,
      'motorina' => Icons.two_wheeler,
      'moto' => Icons.two_wheeler,
      'auto' => Icons.directions_car,
      'camioneta' => Icons.local_shipping,
      'camion' => Icons.local_fire_department,
      _ => Icons.delivery_dining,
    };
  }

  String _vehiculoLabel(String? vehiculo) {
    return switch (vehiculo) {
      'bicicleta' => 'Bicicleta',
      'motorina' => 'Motorina',
      'moto' => 'Moto',
      'auto' => 'Auto',
      'camioneta' => 'Camioneta',
      'camion' => 'Camion',
      _ => 'Repartidor',
    };
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({required this.entrega});

  final DeliveryEntregaModel entrega;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = entrega.moneda ?? 'CUP';
    final distance = entrega.ruta?['distance'];
    final duration = entrega.ruta?['duration'];
    final rutaDistance = distance is num
        ? distance.toDouble()
        : double.tryParse('$distance');
    final rutaDuration = duration is num
        ? duration.toDouble()
        : double.tryParse('$duration');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(
              Icons.storefront_rounded,
              entrega.negocioNombre ?? 'Negocio',
              entrega.negocioDireccion,
            ),
            _row(
              Icons.location_on_outlined,
              entrega.clienteNombre ?? 'Cliente',
              entrega.clienteDireccionEntrega,
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(
                  theme,
                  Icons.straighten_rounded,
                  rutaDistance != null
                      ? _formatDistance(rutaDistance)
                      : _formatDistance(entrega.distanciaTotalKm),
                ),
                if (rutaDuration != null)
                  _chip(
                    theme,
                    Icons.schedule_rounded,
                    _formatMinutes(rutaDuration),
                  ),
                _chip(
                  theme,
                  Icons.payments_outlined,
                  '${entrega.tarifaEstimada?.toStringAsFixed(2) ?? '-'} $currency',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null && subtitle.isNotEmpty) Text(subtitle),
              ],
            ),
          ),
        ],
      ),
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
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppColorsForRoute {
  static const origin = Color(0xFF2E7D32);
  static const destination = Color(0xFFC62828);
}

String _formatDistance(double? km) {
  if (km == null) return '-';
  if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
  return '${km.toStringAsFixed(1)} km';
}

String _formatMinutes(double minutes) {
  if (minutes < 1) return '${(minutes * 60).toStringAsFixed(0)} min';
  return '${minutes.toStringAsFixed(0)} min';
}