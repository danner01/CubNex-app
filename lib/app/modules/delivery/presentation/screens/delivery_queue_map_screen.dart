import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/environment/app_environment.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/delivery/delivery_accepted_store.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../../blocs/delivery/delivery_state.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../widgets/delivery_common.dart';

class DeliveryQueueMapScreen extends StatefulWidget {
  const DeliveryQueueMapScreen({super.key});

  @override
  State<DeliveryQueueMapScreen> createState() => _DeliveryQueueMapScreenState();
}

class _DeliveryQueueMapScreenState extends State<DeliveryQueueMapScreen> {
  static final _defaultCenter = Position(-82.3666, 23.1136);
  static const _pollInterval = Duration(seconds: 15);
  static const _originColor = Color(0xFF2E7D32);
  static const _destinationColor = Color(0xFFD32F2F);
  static const _routeColor = Color(0xFF1E88E5);

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _polylineManager;
  bool _didInitialCamera = false;
  Position? _lastUserPos;
  Timer? _pollTimer;

  bool get _hasToken => AppEnvironment.mapboxAccessToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasToken) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_refreshQueue()),
    );
    unawaited(_refreshQueue(initial: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_pointManager?.deleteAll());
    unawaited(_polylineManager?.deleteAll());
    super.dispose();
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

  Future<void> _refreshQueue({bool initial = false}) async {
    final cubit = context.read<DeliveryCubit>();
    try {
      final position = await _currentPosition();
      if (position != null) {
        _lastUserPos = Position(position.longitude, position.latitude);
        await cubit.reportLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (_) {
      // Continua cargando la cola aunque falle el reporte de posicion.
    }
    await cubit.loadDisponibles(silent: !initial);
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();
    await _syncMarkers(initial: true);
  }

  Future<void> _syncMarkers({required bool initial}) async {
    final map = _mapboxMap;
    final pointManager = _pointManager;
    final polylineManager = _polylineManager;
    if (map == null || pointManager == null || polylineManager == null) return;

    final items = List<DeliveryEntregaModel>.from(
      context.read<DeliveryCubit>().state.availableEntregas,
    );

    final coords = <List<double>>[];

    try {
      await polylineManager.deleteAll();
      await pointManager.deleteAll();

      for (final entrega in items) {
        final originLat = entrega.negocioLatitude;
        final originLng = entrega.negocioLongitude;
        final destLat = entrega.destinoLatitude ?? entrega.negocioLatitude;
        final destLng = entrega.destinoLongitude ?? entrega.negocioLongitude;
        if (originLat == null || originLng == null) continue;
        coords.add([originLng, originLat]);
        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(originLng, originLat)),
            iconImage: 'marker',
            iconColor: _originColor.toARGB32(),
            iconSize: 1.0,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
        if (destLat != null && destLng != null) {
          coords.add([destLng, destLat]);
          await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(destLng, destLat)),
              iconImage: 'marker',
              iconColor: _destinationColor.toARGB32(),
              iconSize: 1.0,
              iconAnchor: IconAnchor.BOTTOM,
            ),
          );
          await polylineManager.create(
            PolylineAnnotationOptions(
              geometry: LineString(
                coordinates: [
                  Position(originLng, originLat),
                  Position(destLng, destLat),
                ],
              ),
              lineColor: _routeColor.toARGB32(),
              lineWidth: 3.4,
              lineOpacity: 0.7,
            ),
          );
        }
      }
    } catch (_) {
      // Si falla la sincronizacion de anotaciones, se conserva el estado previo.
    }

    if (initial && !_didInitialCamera) {
      if (coords.isNotEmpty) {
        final center = _bboxCenter(coords);
        if (center != null) {
          _didInitialCamera = true;
          await map.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(center[0], center[1])),
              zoom: _zoomFor(coords),
            ),
            MapAnimationOptions(duration: 400),
          );
        }
      } else if (_lastUserPos != null) {
        final lastUserPos = _lastUserPos;
        if (lastUserPos != null) {
          _didInitialCamera = true;
          await map.flyTo(
            CameraOptions(
              center: Point(coordinates: lastUserPos),
              zoom: 13,
            ),
            MapAnimationOptions(duration: 400),
          );
        }
      }
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de entregas en el mapa'),
        actions: [
          IconButton(
            onPressed: () => unawaited(_refreshQueue()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar cola',
          ),
        ],
      ),
      body: BlocListener<DeliveryCubit, DeliveryState>(
        listener: (context, state) {
          if (_mapboxMap == null || _pointManager == null) return;
          if (!_didInitialCamera || state.availableEntregas.isNotEmpty) {
            unawaited(_syncMarkers(initial: !_didInitialCamera));
          }
        },
        child: BlocBuilder<DeliveryCubit, DeliveryState>(
          builder: (context, state) {
            return Stack(
            children: [
              if (_hasToken)
                MapWidget(
                  // ignore: deprecated_member_use
                  cameraOptions: CameraOptions(
                    center: Point(coordinates: _defaultCenter),
                    zoom: 11,
                  ),
                  onMapCreated: _onMapCreated,
                )
              else
                const _MapTokenErrorPanel(),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(_originColor, 'Recogida'),
                    const SizedBox(width: 10),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.chevron_right_rounded)],
                    ),
                    const SizedBox(width: 10),
                    _LegendDot(_destinationColor, 'Entrega'),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomPanel(context, state),
              ),
            ],
          );
          },
        ),
      ),
    );
  }

  Future<void> _confirmAccept(
    DeliveryEntregaModel entrega, {
    required bool startRoute,
  }) async {
    if (!startRoute) {
      await context.read<DeliveryCubit>().aceptar(entrega.id);
      return;
    }
    final position = await _currentPosition();
    if (!mounted) return;
    if (position == null) {
      showSnackOrAuthDialog(
        context,
        'No se pudo confirmar tu ubicacion para iniciar la ruta.',
      );
      return;
    }
    await context
        .read<DeliveryCubit>()
        .reportLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        )
        .catchError((_) {});
    if (!mounted) return;
    await context.read<DeliveryCubit>().aceptar(entrega.id);
    sl<DeliveryAcceptedStore>().accept(entrega);
    if (mounted) context.go(AppRoutes.deliveryRoute);
  }

  Widget _buildBottomPanel(BuildContext context, DeliveryState state) {
    final items = state.availableEntregas;
    if (state.status == DeliveryStatus.loading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      final error = state.queueError;
      if (error != null && error.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () => unawaited(_refreshQueue()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const DeliveryMessageCard(
        message: 'No hay entregas disponibles por ahora.',
      );
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.2,
      maxChildSize: 0.62,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _QueueMapItemCard(
                  entrega: items[i],
                  index: i,
                  accepting: state.acceptingEntregaId == items[i].id,
                  onAccept: () => unawaited(
                    context.read<DeliveryCubit>().aceptar(items[i].id),
                  ),
                  onStartRoute: () => unawaited(
                    _confirmAccept(items[i], startRoute: true),
                  ),
                ),
                if (i != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MapTokenErrorPanel extends StatelessWidget {
  const _MapTokenErrorPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'No se pudo cargar el mapa',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Configuracion invalida de Mapbox. Vuelve a intentarlo mas '
                'tarde.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(
                  context.read<DeliveryCubit>().loadDisponibles(),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: Colors.white,
      label: Text(label),
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 6,
      ),
    );
  }
}

class _QueueMapItemCard extends StatelessWidget {
  const _QueueMapItemCard({
    required this.entrega,
    required this.index,
    required this.accepting,
    required this.onAccept,
    required this.onStartRoute,
  });

  final DeliveryEntregaModel entrega;
  final int index;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onStartRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = entrega.moneda ?? 'CUP';
    final isPaquete = entrega.tipo == 'paquete';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPaquete
                        ? '${entrega.remitenteNombre ?? 'Paquete'} -> ${entrega.destinatarioNombre ?? entrega.clienteNombre ?? '-'}'
                        : '${entrega.negocioNombre ?? 'Negocio'} -> ${entrega.clienteNombre ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DeliveryMetaChip(
                  icon: Icons.payments_outlined,
                  label: formatDeliveryMoney(
                    entrega.paqueteTarifa ?? entrega.tarifaEstimada,
                    currency,
                  ),
                ),
                DeliveryMetaChip(
                  icon: Icons.straighten_rounded,
                  label: formatDeliveryDistance(entrega.distanciaTotalKm),
                ),
                if (isPaquete && entrega.paqueteDescripcion != null)
                  DeliveryMetaChip(
                    icon: Icons.inventory_2_outlined,
                    label: entrega.paqueteDescripcion!,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: accepting ? null : onAccept,
                icon: accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.handshake_outlined),
                label: Text(accepting ? 'Aceptando...' : 'Aceptar entrega'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: accepting ? null : onStartRoute,
                icon: const Icon(Icons.route_rounded, size: 18),
                label: const Text('Iniciar ruta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}