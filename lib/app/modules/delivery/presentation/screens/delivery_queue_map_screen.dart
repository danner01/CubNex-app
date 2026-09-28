import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/environment/app_environment.dart';
import '../../../../config/http/api_client.dart';
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

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _polylineManager;
  bool _didInitialCamera = false;
  Position? _lastUserPos;
  double? _myLat;
  double? _myLng;
  bool _locating = false;
  bool _drawingRoute = false;
  List<List<double>>? _acceptedRouteCoords;
  String? _acceptedRouteId;
  Timer? _pollTimer;

  bool get _hasToken => AppEnvironment.mapboxAccessToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasToken) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = sl<DeliveryCubit>();
      final status = cubit.state.status;
      if (status == DeliveryStatus.initial ||
          status == DeliveryStatus.failure) {
        unawaited(cubit.load());
      }
    });
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

  void _storePosition(geo.Position position) {
    final lng = position.longitude;
    final lat = position.latitude;
    final changed = _myLat != lat || _myLng != lng;
    _lastUserPos = Position(lng, lat);
    if (changed && mounted) {
      setState(() {
        _myLat = lat;
        _myLng = lng;
      });
    }
  }

  Future<void> _refreshQueue({bool initial = false}) async {
    final cubit = context.read<DeliveryCubit>();
    try {
      final position = await _currentPosition();
      if (position != null) {
        _storePosition(position);
        await cubit.reportLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (_mapboxMap != null && !_didInitialCamera) {
          await _syncAnnotations(initial: true);
        }
      }
    } catch (_) {
      // Continua cargando la cola aunque falle el reporte de posicion.
    }
    await cubit.loadDisponibles(silent: !initial);
  }

  void _retry() {
    final cubit = context.read<DeliveryCubit>();
    if (cubit.state.status == DeliveryStatus.failure ||
        cubit.state.profile == null) {
      unawaited(cubit.load());
    } else {
      unawaited(_refreshQueue());
    }
  }

  Future<void> _locateCurrentPos() async {
    setState(() => _locating = true);
    final position = await _currentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() => _locating = false);
      showSnackOrAuthDialog(
        context,
        'No se pudo obtener tu ubicacion. Activa el permiso de ubicacion e '
        'intenta de nuevo.',
      );
      return;
    }
    _storePosition(position);
    _didInitialCamera = false;
    await _syncAnnotations(initial: true);
    if (!mounted) return;
    setState(() => _locating = false);
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _polylineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    await _syncAnnotations(initial: true);
  }

  List<List<double>>? _routePointsFor(DeliveryEntregaModel entrega) {
    if (entrega.rutaCoordenadas != null &&
        entrega.rutaCoordenadas!.length >= 2) {
      return entrega.rutaCoordenadas;
    }
    if (_acceptedRouteId == entrega.id && _acceptedRouteCoords != null) {
      return _acceptedRouteCoords;
    }
    return null;
  }

  Future<void> _ensureAcceptedRoute(DeliveryEntregaModel entrega) async {
    if (_acceptedRouteId == entrega.id) return;
    if (entrega.rutaCoordenadas != null &&
        entrega.rutaCoordenadas!.length >= 2) {
      _acceptedRouteId = entrega.id;
      return;
    }
    final originLat = entrega.negocioLatitude;
    final originLng = entrega.negocioLongitude;
    final destLat = entrega.destinoLatitude;
    final destLng = entrega.destinoLongitude;
    if (originLat == null ||
        originLng == null ||
        destLat == null ||
        destLng == null) {
      return;
    }
    _acceptedRouteId = entrega.id;
    if (mounted) setState(() => _drawingRoute = true);
    final result = await sl<ApiClient>().post<Map<String, dynamic>>(
      '/mapbox/ruta',
      data: {
        'origen': {'lat': originLat, 'lng': originLng},
        'destino': {'lat': destLat, 'lng': destLng},
      },
      parser: (json) =>
          json is Map ? Map<String, dynamic>.from(json) : const {},
    );
    if (!mounted) return;
    final parsed = <List<double>>[];
    if (result.isSuccess) {
      final routes = result.data?['routes'];
      if (routes is List && routes.isNotEmpty) {
        final first = routes.first;
        if (first is Map) {
          final geometry = first['geometry'];
          final coords = geometry is Map ? geometry['coordinates'] : null;
          if (coords is List) {
            for (final entry in coords) {
              if (entry is List && entry.length >= 2) {
                final lng = (entry[0] as num?)?.toDouble();
                final lat = (entry[1] as num?)?.toDouble();
                if (lng != null && lat != null) parsed.add([lng, lat]);
              }
            }
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _drawingRoute = false;
      if (parsed.length >= 2) _acceptedRouteCoords = parsed;
    });
    await _syncAnnotations(initial: false);
  }

  Future<void> _syncAnnotations({required bool initial}) async {
    final map = _mapboxMap;
    final pointManager = _pointManager;
    final polylineManager = _polylineManager;
    if (map == null || pointManager == null || polylineManager == null) return;

    final accepted = sl<DeliveryAcceptedStore>().accepted.value;
    final items = List<DeliveryEntregaModel>.from(
      context.read<DeliveryCubit>().state.availableEntregas,
    );
    final entries = <DeliveryEntregaModel>[
      if (accepted != null && !items.any((item) => item.id == accepted.id))
        accepted,
      ...items,
    ];

    final coords = <List<double>>[];

    try {
      await polylineManager.deleteAll();
      await pointManager.deleteAll();

      for (final entrega in entries) {
        final originLat = entrega.negocioLatitude;
        final originLng = entrega.negocioLongitude;
        final destLat = entrega.destinoLatitude;
        final destLng = entrega.destinoLongitude;
        final route = _routePointsFor(entrega);

        if (originLat != null && originLng != null) {
          coords.add([originLng, originLat]);
          await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(originLng, originLat)),
              iconImage: 'marker',
              iconColor: DeliveryRouteColors.origin.toARGB32(),
              iconSize: 1.0,
              iconAnchor: IconAnchor.BOTTOM,
            ),
          );
        }

        if (destLat != null && destLng != null) {
          coords.add([destLng, destLat]);
          await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(destLng, destLat)),
              iconImage: 'marker',
              iconColor: DeliveryRouteColors.destination.toARGB32(),
              iconSize: 1.0,
              iconAnchor: IconAnchor.BOTTOM,
            ),
          );
        }

        final geometry =
            route ??
            (originLat != null &&
                    originLng != null &&
                    destLat != null &&
                    destLng != null
                ? <List<double>>[
                    [originLng, originLat],
                    [destLng, destLat],
                  ]
                : null);
        if (geometry != null && geometry.length >= 2) {
          coords.addAll(geometry);
          await polylineManager.create(
            PolylineAnnotationOptions(
              geometry: LineString(
                coordinates: geometry
                    .map((point) => Position(point[0], point[1]))
                    .toList(),
              ),
              lineColor: DeliveryRouteColors.route.toARGB32(),
              lineWidth: 3.4,
              lineOpacity: 0.75,
            ),
          );
        }
      }
    } catch (_) {
      // Si falla la sincronizacion de anotaciones, se conserva el estado previo.
    }

    final lastUserPos = _lastUserPos;
    if (lastUserPos != null) {
      final iconId = await ensureDeliveryMarkerIcon(
        map,
        const Color(0xFF00ACC1),
        null,
      );
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: lastUserPos),
          iconImage: iconId ?? 'marker',
          iconColor: iconId == null ? const Color(0xFF00ACC1).toARGB32() : null,
          iconSize: 0.9,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    if (initial && !_didInitialCamera) {
      final anchor = _preferredCameraAnchor(coords);
      if (anchor != null) {
        _didInitialCamera = true;
        await map.flyTo(
          CameraOptions(
            center: Point(coordinates: anchor),
            zoom: _zoomFor(coords),
          ),
          MapAnimationOptions(duration: 400),
        );
      }
    }
  }

  Position? _preferredCameraAnchor(List<List<double>> coords) {
    if (_lastUserPos != null) return _lastUserPos;
    if (coords.isNotEmpty) {
      final center = _bboxCenter(coords);
      if (center != null) return Position(center[0], center[1]);
    }
    return null;
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
    _storePosition(position);
    await context
        .read<DeliveryCubit>()
        .reportLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        )
        .catchError((_) {});
    if (!mounted) return;
    await context.read<DeliveryCubit>().aceptar(entrega.id);
    if (mounted) context.push(AppRoutes.deliveryRoute);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<DeliveryCubit>(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cola de entregas en el mapa'),
          actions: [
            IconButton(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar cola',
            ),
          ],
        ),
        body: ValueListenableBuilder<DeliveryEntregaModel?>(
          valueListenable: sl<DeliveryAcceptedStore>().accepted,
          builder: (context, accepted, _) {
            final theme = Theme.of(context);
            if (accepted != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) unawaited(_ensureAcceptedRoute(accepted));
              });
            }
            final initialCenter = _myLat != null && _myLng != null
                ? Point(coordinates: Position(_myLng!, _myLat!))
                : (_acceptedRouteCoords != null &&
                          _acceptedRouteCoords!.length >= 2
                      ? Point(
                          coordinates: Position(
                            _acceptedRouteCoords!.first[0],
                            _acceptedRouteCoords!.first[1],
                          ),
                        )
                      : Point(coordinates: _defaultCenter));
            return Stack(
              children: [
                if (_hasToken)
                  Positioned.fill(
                    child: MapWidget(
                      // ignore: deprecated_member_use
                      cameraOptions: CameraOptions(
                        center: initialCenter,
                        zoom: 13,
                      ),
                      onMapCreated: _onMapCreated,
                    ),
                  )
                else
                  const Positioned.fill(child: _MapTokenErrorPanel()),
                if (_mapboxMap != null)
                  Positioned.fill(
                    child: SafeArea(
                      bottom: false,
                      child: DeliveryMapSearchOverlay(
                        mapboxMap: _mapboxMap!,
                        label: 'Buscar direccion en el mapa...',
                        onFocusLocation: _onFocusLocation,
                        onUseCurrentLocation: _locateCurrentPos,
                        showLocateFab: false,
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  right: 12,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FloatingActionButton.small(
                        heroTag: 'queue_map_locate',
                        tooltip: 'Centrar en mi ubicacion',
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: const Color(0xFF00ACC1),
                        onPressed: _locating
                            ? null
                            : () => unawaited(_locateCurrentPos()),
                        child: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: BlocListener<DeliveryCubit, DeliveryState>(
                    listener: (context, state) {
                      if (_mapboxMap == null || _pointManager == null) return;
                      if (!_didInitialCamera ||
                          state.availableEntregas.isNotEmpty) {
                        unawaited(
                          _syncAnnotations(initial: !_didInitialCamera),
                        );
                      }
                    },
                    child: BlocBuilder<DeliveryCubit, DeliveryState>(
                      builder: (context, state) {
                        return _buildPanel(context, state, accepted);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _onFocusLocation(double lat, double lng) async {
    _didInitialCamera = true;
    await _mapboxMap?.flyTo(
      CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 15),
      MapAnimationOptions(duration: 400),
    );
    await _syncAnnotations(initial: false);
  }

  Widget _buildPanel(
    BuildContext context,
    DeliveryState state,
    DeliveryEntregaModel? accepted,
  ) {
    final theme = Theme.of(context);
    final items = state.availableEntregas;
    final hasAccepted = accepted != null;
    final isLoading = state.status == DeliveryStatus.loading && items.isEmpty;
    final isFailure = state.status == DeliveryStatus.failure && items.isEmpty;
    final profile = state.profile;
    final queueError = state.queueError;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        initialChildSize: isLoading || isFailure
            ? 0.3
            : items.isEmpty && !hasAccepted
            ? 0.3
            : 0.4,
        minChildSize: 0.24,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.24, 0.4, 0.62, 0.85],
        builder: (context, sheetController) {
          return DeliverySheetPanel(
            controller: sheetController,
            child: ListView(
              controller: sheetController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  'Cola de entregas',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAccepted
                      ? 'Mostrando tu entrega activa y las entregas disponibles cerca.'
                      : 'Acepta una entrega para ver su ruta en el mapa.',
                ),
                const SizedBox(height: 14),
                DeliveryMapLegendRow(
                  myColor: const Color(0xFF00ACC1),
                  showAcceptRoute: hasAccepted || items.isNotEmpty,
                  showManualRoute: false,
                ),
                const SizedBox(height: 12),
                if (_myLat == null) ...[
                  _QueueLocatePrompt(
                    locating: _locating,
                    onRetry: () => unawaited(_locateCurrentPos()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (isFailure)
                  _QueueErrorBlock(
                    message:
                        state.errorMessage ??
                        queueError ??
                        'No se pudo cargar la cola de entregas.',
                    onRetry: _retry,
                  ),
                if (profile == null && !isLoading)
                  const DeliveryMessageCard(
                    message:
                        'Registra tu perfil delivery para ver la cola de entregas '
                        'en el mapa.',
                  ),
                if (profile != null && !profile.available && !isLoading)
                  _QueueErrorBlock(
                    message:
                        'Activa tu disponibilidad para ver la cola de entregas '
                        'en el mapa.',
                    actionLabel: 'Abrir panel delivery',
                    onRetry: () => context.push(AppRoutes.deliveryProfile),
                  ),
                if (hasAccepted) ...[
                  _AcceptedDeliveryCard(
                    entrega: accepted,
                    drawingRoute: _drawingRoute,
                    onContinue: () => context.push(AppRoutes.deliveryRoute),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!isLoading && !isFailure && profile?.available == true) ...[
                  if (queueError != null &&
                      queueError.isNotEmpty &&
                      items.isEmpty)
                    _QueueErrorBlock(message: queueError, onRetry: _retry),
                  if (items.isEmpty &&
                      (queueError == null || queueError.isEmpty))
                    const DeliveryMessageCard(
                      message:
                          'No hay entregas disponibles por ahora.\n\nSolo aparecen '
                          'los pedidos que el cliente pidio con reparto, dentro de '
                          'tu radio de operacion y con tu disponibilidad activa.',
                    ),
                  if (items.isNotEmpty) ...[
                    Text(
                      'Disponibles (${items.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QueueLocatePrompt extends StatelessWidget {
  const _QueueLocatePrompt({required this.locating, required this.onRetry});

  final bool locating;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.location_off_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detectar mi posicion',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Activa el GPS para centrar el mapa en ti y ver la cola de entregas.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: locating ? null : onRetry,
              child: locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Usar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueErrorBlock extends StatelessWidget {
  const _QueueErrorBlock({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Reintentar',
  });

  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptedDeliveryCard extends StatelessWidget {
  const _AcceptedDeliveryCard({
    required this.entrega,
    required this.drawingRoute,
    required this.onContinue,
  });

  final DeliveryEntregaModel entrega;
  final bool drawingRoute;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = entrega.moneda ?? 'CUP';
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: DeliveryRouteColors.route),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: DeliveryRouteColors.route,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Entrega activa: ${entrega.clienteNombre ?? entrega.destinatarioNombre ?? '-'}',
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
            Text(
              entrega.clienteDireccionEntrega ??
                  entrega.negocioDireccion ??
                  '-',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
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
                DeliveryMetaChip(
                  icon: Icons.route_rounded,
                  label: drawingRoute
                      ? 'Calculando ruta...'
                      : 'Ruta en el mapa',
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Continuar entrega'),
              ),
            ),
          ],
        ),
      ),
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
                onPressed: () {
                  final cubit = context.read<DeliveryCubit>();
                  if (cubit.state.profile == null ||
                      cubit.state.status == DeliveryStatus.failure) {
                    unawaited(cubit.load());
                  } else {
                    unawaited(cubit.loadDisponibles());
                  }
                },
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
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
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
