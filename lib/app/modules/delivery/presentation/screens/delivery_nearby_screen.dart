import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/http/api_client.dart';
import '../../data/models/delivery_activo_model.dart';
import '../widgets/delivery_common.dart';

class DeliveryNearbyScreen extends StatefulWidget {
  const DeliveryNearbyScreen({super.key});

  @override
  State<DeliveryNearbyScreen> createState() => _DeliveryNearbyScreenState();
}

class _DeliveryNearbyScreenState extends State<DeliveryNearbyScreen> {
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

  final ApiClient _apiClient = sl<ApiClient>();

  final List<DeliveryActivoModel> _items = [];
  Timer? _pollTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;
  double? _myLat;
  double? _myLng;
  bool _didInitialCamera = false;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;

  @override
  void initState() {
    super.initState();
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
        await _syncMarkers(initial: !_didInitialCamera);
      } else {
        setState(() {
          _loading = false;
          _errorMessage =
              result.error?.message ??
              'No se pudieron cargar los repartidores.';
        });
        await _syncMarkers(initial: false);
      }
    } finally {
      _refreshing = false;
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _pointManager?.setIconAllowOverlap(true);
    await _syncMarkers(initial: true);
  }

  Future<void> _syncMarkers({required bool initial}) async {
    final manager = _pointManager;
    if (manager == null) return;
    await manager.deleteAll();

    var minLat = double.infinity, maxLat = double.negativeInfinity;
    var minLng = double.infinity, maxLng = double.negativeInfinity;
    final items = List<DeliveryActivoModel>.from(_items);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final lat = item.ultimaUbicacion?.lat;
      final lng = item.ultimaUbicacion?.lng;
      if (lat == null || lng == null) continue;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      await manager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconImage: 'marker',
          iconColor: _markerColor(item, i).toARGB32(),
          iconSize: 1.15,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    if (!initial) return;
    _didInitialCamera = true;
    final hasMyPosition = _myLat != null && _myLng != null;
    if (!hasMyPosition && minLng.isInfinite) return;
    final center = hasMyPosition
        ? Point(coordinates: Position(_myLng!, _myLat!))
        : Point(
            coordinates: Position((minLng + maxLng) / 2, (minLat + maxLat) / 2),
          );
    await _mapboxMap?.flyTo(
      CameraOptions(center: center, zoom: hasMyPosition ? 13 : 12),
      MapAnimationOptions(duration: 400),
    );
  }

  Color _markerColor(DeliveryActivoModel item, int index) {
    final custom = parseDeliveryMarkerColor(item.colorMarcador);
    if (custom != null) return custom;
    return _palette[index % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repartidores cerca'),
        actions: [
          IconButton(
            onPressed: () => unawaited(_refresh()),
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _items.isEmpty
                      ? 'Buscando repartidores activos...'
                      : '${_items.length} repartidores disponibles cercanos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _myLat == null
                      ? 'Sin ubicacion del dispositivo. Para los negocios se usan las coordenadas de tu tienda.'
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
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: _loading && _items.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFE8EAED),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : MapWidget(
                      // ignore: deprecated_member_use
                      cameraOptions: CameraOptions(
                        center: _myLat != null && _myLng != null
                            ? Point(coordinates: Position(_myLng!, _myLat!))
                            : Point(coordinates: _defaultCenter),
                        zoom: 12,
                      ),
                      onMapCreated: _onMapCreated,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _MessageCard(
                    message:
                        _errorMessage ??
                        'No hay repartidores disponibles en estos momentos.',
                    onRetry: () => unawaited(_refresh()),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _DeliveryActivoCard(item: _items[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryActivoCard extends StatelessWidget {
  const _DeliveryActivoCard({required this.item});

  final DeliveryActivoModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = item.distanciaKm.toStringAsFixed(1);
    final rating = item.calificacionPromedio.toStringAsFixed(1);

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
          radius: 26,
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.16),
          backgroundImage: item.avatarUrl?.isNotEmpty == true
              ? NetworkImage(item.avatarUrl!)
              : null,
          child: item.avatarUrl?.isNotEmpty == true
              ? null
              : Icon(
                  _vehiculoIcon(item.tipoVehiculo),
                  color: theme.colorScheme.secondary,
                ),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              [
                _vehiculoLabel(item.tipoVehiculo),
                if (item.placa != null && item.placa!.isNotEmpty) item.placa,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(theme, Icons.star_rounded, rating),
                _chip(
                  theme,
                  Icons.inventory_2_outlined,
                  '${item.entregasCompletadas} entregas',
                ),
                _chip(
                  theme,
                  Icons.payments_outlined,
                  'Base ${_money(item.tarifaBase)}'
                  '${item.tarifaPorKm > 0 ? ' + ${_money(item.tarifaPorKm)}/km' : ''}',
                ),
                _chip(
                  theme,
                  Icons.check_circle_rounded,
                  'Disponible',
                  green: true,
                ),
                if (parseDeliveryMarkerColor(item.colorMarcador) != null)
                  _colorChip(
                    theme,
                    parseDeliveryMarkerColor(item.colorMarcador)!,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _chip(
    ThemeData theme,
    IconData icon,
    String label, {
    bool green = false,
  }) {
    final color = green ? Colors.green.shade700 : theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorChip(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            'Marcador',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
