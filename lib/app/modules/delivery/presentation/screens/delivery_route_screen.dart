import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/environment/app_environment.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/delivery/delivery_accepted_store.dart';
import '../../data/models/delivery_entrega_model.dart';

class DeliveryRouteScreen extends StatefulWidget {
  const DeliveryRouteScreen({super.key});

  @override
  State<DeliveryRouteScreen> createState() => _DeliveryRouteScreenState();
}

class _DeliveryRouteScreenState extends State<DeliveryRouteScreen> {
  PolylineAnnotationManager? _routeManager;
  PointAnnotationManager? _pointManager;
  late final bool _tokenReady;

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<DeliveryEntregaModel?>(
        valueListenable: sl<DeliveryAcceptedStore>().accepted,
        builder: (context, entrega, _) {
          final route = entrega?.rutaCoordenadas ?? const <List<double>>[];
          final coords = route.isNotEmpty
              ? route
              : (entrega != null &&
                        entrega.negocioLatitude != null &&
                        entrega.negocioLongitude != null
                    ? <List<double>>[
                        [entrega.negocioLongitude!, entrega.negocioLatitude!],
                      ]
                    : const <List<double>>[]);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Ruta y mapa',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Entrega aceptada y ruta hacia el cliente.'),
              const SizedBox(height: 16),
              if (entrega == null)
                const _RouteEmptyCard()
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 340,
                    child: coords.isEmpty
                        ? const Center(child: Text('Sin ruta disponible.'))
                        : _buildMap(coords),
                  ),
                ),
                const SizedBox(height: 14),
                _RouteSummaryCard(entrega: entrega),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(List<List<double>> coords) {
    if (coords.isEmpty) return const SizedBox.shrink();
    final first = coords.first;
    return MapWidget(
      // ignore: deprecated_member_use
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(first[0], first[1])),
        zoom: 12.5,
      ),
      onMapCreated: (mapboxMap) async {
        await mapboxMap.gestures.updateSettings(
          GesturesSettings(
            scrollEnabled: true,
            pinchToZoomEnabled: true,
            rotateEnabled: true,
            pitchEnabled: true,
            doubleTapToZoomInEnabled: true,
            doubleTouchToZoomOutEnabled: true,
          ),
        );
        _routeManager = await mapboxMap.annotations
            .createPolylineAnnotationManager();
        _pointManager = await mapboxMap.annotations
            .createPointAnnotationManager();
        _pointManager?.setIconAllowOverlap(true);
        await _syncAnnotations();
        final center = _bboxCenter(coords);
        if (center != null) {
          await mapboxMap.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(center[0], center[1])),
              zoom: _zoomFor(coords),
            ),
            MapAnimationOptions(duration: 500),
          );
        }
      },
    );
  }

  Future<void> _syncAnnotations() async {
    final entrega = sl<DeliveryAcceptedStore>().accepted.value;
    if (entrega == null) return;
    await _routeManager?.deleteAll();
    await _pointManager?.deleteAll();
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
      return;
    }
    if (route != null && route.isNotEmpty) {
      await _addMarker(route.first, AppColorsForRoute.origin);
      return;
    }
    if (entrega.negocioLongitude != null && entrega.negocioLatitude != null) {
      await _addMarker([
        entrega.negocioLongitude!,
        entrega.negocioLatitude!,
      ], AppColorsForRoute.origin);
    }
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

class _RouteEmptyCard extends StatelessWidget {
  const _RouteEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Aun no tienes una entrega aceptada. Acepta una entrega desde el '
          'panel para ver la ruta hasta el cliente.',
          textAlign: TextAlign.center,
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
