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
  String? _locationError;
  DeliveryEntregaModel? _focusEntrega;
  String? _focusEntregaId;
  String? _loadingRouteFor;
  bool _routesFetchInProgress = false;
  final Map<String, List<List<double>>> _routeCache = {};
  List<List<double>>? _acceptedRouteCoords;
  bool _autoCentered = false;
  Timer? _pollTimer;

  bool get _hasToken => AppEnvironment.mapboxAccessToken.isNotEmpty;

  static const _maxQueuedRoutes = 6;

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
      unawaited(_loadFocusEntrega());
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

  void _storePosition(geo.Position position) {
    final lng = position.longitude;
    final lat = position.latitude;
    final hadPosition = _lastUserPos != null;
    _lastUserPos = Position(lng, lat);
    final changed = _myLat != lat || _myLng != lng;
    if (changed && mounted) {
      setState(() {
        _myLat = lat;
        _myLng = lng;
        if (_locationError != null) _locationError = null;
      });
    }
    if (!hadPosition && _focusEntrega == null && !_autoCentered && mounted) {
      _autoCentered = true;
      unawaited(_centerOnUser());
    }
  }

  /// Centra la camara en la posicion del repartidor la primera vez que se
  /// obtiene, aunque llegue despues de que el mapa termino de cargar. Si el
  /// mapa aun no existe, [_onMapCreated] lo hara al crearse.
  Future<void> _centerOnUser() async {
    final pos = _lastUserPos;
    final map = _mapboxMap;
    if (pos == null || map == null) return;
    if (_focusEntrega != null) return;
    _didInitialCamera = true;
    await map.flyTo(
      CameraOptions(center: Point(coordinates: pos), zoom: 14),
      MapAnimationOptions(duration: 500),
    );
  }

  void _applyLocationResult(DeliveryLocationResult result) {
    if (result.hasPosition) {
      _storePosition(result.position!);
      return;
    }
    debugPrint('DeliveryQueueMap: ubicacion no disponible (${result.status})');
    if (mounted) setState(() => _locationError = result.message);
  }

  Future<geo.Position?> _currentPosition() async {
    final result = await readDeliveryPosition();
    _applyLocationResult(result);
    return result.position;
  }

  Future<void> _loadFocusEntrega() async {
    final id = _requestedEntregaId();
    if (id == null || id.isEmpty) return;
    final result = await sl<ApiClient>().get<DeliveryEntregaModel>(
      '/entregas/$id',
      parser: (json) =>
          DeliveryEntregaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _focusEntrega = result.data;
        _focusEntregaId = id;
      });
      await _ensureRouteFor(result.data!, force: true);
      if (!mounted) return;
      final dest = result.data!;
      if (dest.destinoLatitude != null && dest.destinoLongitude != null) {
        _didInitialCamera = true;
        await _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                dest.destinoLongitude!,
                dest.destinoLatitude!,
              ),
            ),
            zoom: 14,
          ),
          MapAnimationOptions(duration: 500),
        );
      }
    } else {
      debugPrint('DeliveryQueueMap: no se pudo cargar la entrega $id');
    }
  }

  String? _requestedEntregaId() {
    final uri = Uri.tryParse(GoRouterState.of(context).uri.toString());
    if (uri == null) return null;
    final value = uri.queryParameters['entrega'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> _refreshQueue({bool initial = false}) async {
    final cubit = context.read<DeliveryCubit>();
    // La posicion puede tardar (el GPS busca el primer fix); no bloquees la
    // carga de la lista de entregas por eso.
    final positionFuture = _currentPosition();
    await cubit.loadDisponibles(silent: !initial);
    final position = await positionFuture;
    if (position == null || !mounted) return;
    try {
      await cubit.reportLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      debugPrint('DeliveryQueueMap: no se pudo reportar la posicion: $error');
    }
    if (_mapboxMap != null && !_didInitialCamera) {
      await _syncAnnotations(initial: true);
    }
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
    if (mounted) setState(() => _locating = true);
    final result = await readDeliveryPosition();
    if (!mounted) return;
    _applyLocationResult(result);
    if (!result.hasPosition) {
      setState(() => _locating = false);
      showSnackOrAuthDialog(context, result.message);
      return;
    }
    _didInitialCamera = false;
    await _syncAnnotations(initial: true);
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.fromLastKnown) {
      showSnackOrAuthDialog(context, result.message);
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _polylineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    if (_autoCentered && !_didInitialCamera && _lastUserPos != null) {
      _didInitialCamera = true;
      await mapboxMap.flyTo(
        CameraOptions(center: Point(coordinates: _lastUserPos!), zoom: 14),
        MapAnimationOptions(duration: 400),
      );
    }
    await _syncAnnotations(initial: !_didInitialCamera);
  }

  List<List<double>>? _routePointsFor(DeliveryEntregaModel entrega) {
    final backend = entrega.rutaCoordenadas;
    if (backend != null && backend.length >= 2) return backend;
    final cached = _routeCache[entrega.id];
    if (cached != null && cached.length >= 2) return cached;
    return null;
  }

  /// Origen de la entrega: el negocio si lo tiene, si no la posicion actual del
  /// repartidor (que es por donde tiene que ir a recoger).
  ({double lat, double lng})? _originFor(DeliveryEntregaModel entrega) {
    final lat = entrega.negocioLatitude;
    final lng = entrega.negocioLongitude;
    if (lat != null && lng != null) return (lat: lat, lng: lng);
    final myLat = _myLat;
    final myLng = _myLng;
    if (myLat != null && myLng != null) return (lat: myLat, lng: myLng);
    return null;
  }

  bool _hasOriginCoordsFor(DeliveryEntregaModel entrega) =>
      entrega.negocioLatitude != null && entrega.negocioLongitude != null;

  Future<void> _ensureRouteFor(
    DeliveryEntregaModel entrega, {
    bool force = false,
  }) async {
    if (entrega.destinoLatitude == null || entrega.destinoLongitude == null) {
      return;
    }
    if (!force && _routeCache[entrega.id] != null) return;
    if (_loadingRouteFor == entrega.id) return;
    final origin = _originFor(entrega);
    if (origin == null) return;

    _loadingRouteFor = entrega.id;
    if (mounted) setState(() => _drawingRoute = true);
    final coords = await fetchDeliveryStreetRoute(
      originLat: origin.lat,
      originLng: origin.lng,
      destLat: entrega.destinoLatitude!,
      destLng: entrega.destinoLongitude!,
    );
    if (!mounted) return;
    if (coords.length >= 2) {
      _routeCache[entrega.id] = coords;
      if (entrega.id == sl<DeliveryAcceptedStore>().accepted.value?.id) {
        _acceptedRouteCoords = coords;
      }
    } else {
      debugPrint('DeliveryQueueMap: sin ruta por carretera para ${entrega.id}');
    }
    setState(() {
      _loadingRouteFor = null;
      _drawingRoute = false;
    });
    await _syncAnnotations(initial: false);
  }

  Future<void> _ensureAcceptedRoute(DeliveryEntregaModel entrega) async {
    if (entrega.rutaCoordenadas != null &&
        entrega.rutaCoordenadas!.length >= 2) {
      _acceptedRouteCoords = entrega.rutaCoordenadas;
    }
    await _ensureRouteFor(entrega);
  }

  /// Pide las rutas por carretera de las entregas visibles (activa + cola), con tope
  /// para no saturar el backend. Las lineas rectas se pintan mientras llegan.
  Future<void> _ensureVisibleRoutes(List<DeliveryEntregaModel> entries) async {
    if (_routesFetchInProgress) return;
    _routesFetchInProgress = true;
    try {
      var requested = 0;
      for (final entrega in entries) {
        if (requested >= _maxQueuedRoutes) break;
        if (_routeCache[entrega.id] != null) continue;
        if (entrega.rutaCoordenadas != null &&
            entrega.rutaCoordenadas!.length >= 2) {
          continue;
        }
        if (entrega.destinoLatitude == null ||
            entrega.destinoLongitude == null) {
          continue;
        }
        if (_originFor(entrega) == null) continue;
        requested++;
        await _ensureRouteFor(entrega);
      }
    } finally {
      _routesFetchInProgress = false;
    }
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
      if (_focusEntrega != null &&
          accepted?.id != _focusEntrega!.id &&
          !items.any((item) => item.id == _focusEntrega!.id))
        _focusEntrega!,
      if (accepted != null && !items.any((item) => item.id == accepted.id))
        accepted,
      ...items,
    ];

    final coords = <List<double>>[];

    try {
      await polylineManager.deleteAll();
      await pointManager.deleteAll();

      for (final entrega in entries) {
        final origin = _originFor(entrega);
        final originIsBusiness = _hasOriginCoordsFor(entrega);
        final destLat = entrega.destinoLatitude;
        final destLng = entrega.destinoLongitude;
        final route = _routePointsFor(entrega);
        final isFocus = entrega.id == _focusEntregaId;

        if (origin != null) {
          coords.add([origin.lng, origin.lat]);
          await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(origin.lng, origin.lat)),
              iconImage: 'marker',
              iconColor:
                  (originIsBusiness
                          ? DeliveryRouteColors.origin
                          : const Color(0xFF9E9E9E))
                      .toARGB32(),
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
              iconSize: isFocus ? 1.3 : 1.0,
              iconAnchor: IconAnchor.BOTTOM,
            ),
          );
        }

        final geometry =
            route ??
            (origin != null && destLat != null && destLng != null
                ? <List<double>>[
                    [origin.lng, origin.lat],
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
              lineWidth: route == null ? 2 : (isFocus ? 5 : 3.4),
              lineOpacity: route == null ? 0.5 : 0.8,
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'DeliveryQueueMap: fallo pintando el mapa: $error\n$stackTrace',
      );
    }

    final lastUserPos = _lastUserPos;
    if (lastUserPos != null) {
      try {
        final iconId = await ensureDeliveryMarkerIcon(
          map,
          const Color(0xFF00ACC1),
          null,
        );
        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: lastUserPos),
            iconImage: iconId ?? 'marker',
            iconColor: iconId == null
                ? const Color(0xFF00ACC1).toARGB32()
                : null,
            iconSize: 0.9,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      } catch (error) {
        debugPrint('DeliveryQueueMap: fallo pintando tu posicion: $error');
      }
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

    unawaited(_ensureVisibleRoutes(entries));
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
                if (_locationError != null) ...[
                  _QueueErrorBlock(
                    message: _locationError!,
                    actionLabel: 'Reintentar ubicacion',
                    onRetry: () => unawaited(_locateCurrentPos()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_myLat == null && _locationError == null) ...[
                  _QueueLocatePrompt(
                    locating: _locating,
                    onRetry: () => unawaited(_locateCurrentPos()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_drawingRoute) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 10),
                  Text(
                    'Trazando la ruta por carretera...',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_focusEntrega != null) ...[
                  _FocusDeliveryCard(
                    entrega: _focusEntrega!,
                    loadingRoute: _loadingRouteFor == _focusEntrega!.id,
                    onGenerateRoute: () =>
                        unawaited(_ensureRouteFor(_focusEntrega!, force: true)),
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

class _FocusDeliveryCard extends StatelessWidget {
  const _FocusDeliveryCard({
    required this.entrega,
    required this.loadingRoute,
    required this.onGenerateRoute,
  });

  final DeliveryEntregaModel entrega;
  final bool loadingRoute;
  final VoidCallback onGenerateRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = entrega.moneda ?? 'CUP';
    final sinCoordenadas =
        entrega.destinoLatitude == null || entrega.destinoLongitude == null;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.map_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pedido asignado: '
                    '${entrega.clienteNombre ?? entrega.destinatarioNombre ?? '-'}',
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
                  'Sin direccion de entrega',
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
                if (entrega.distanciaTotalKm != null)
                  DeliveryMetaChip(
                    icon: Icons.straighten_rounded,
                    label: formatDeliveryDistance(entrega.distanciaTotalKm),
                  ),
                DeliveryMetaChip(
                  icon: Icons.route_rounded,
                  label: sinCoordenadas
                      ? 'Sin coordenadas'
                      : loadingRoute
                      ? 'Generando ruta...'
                      : 'Ruta en el mapa',
                ),
              ],
            ),
            if (sinCoordenadas) ...[
              const SizedBox(height: 8),
              Text(
                'Este pedido no tiene coordenadas de entrega, por eso no se puede '
                'trazar la ruta en el mapa.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loadingRoute ? null : onGenerateRoute,
                  icon: loadingRoute
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route_rounded, size: 18),
                  label: Text(
                    loadingRoute ? 'Generando ruta...' : 'Generar ruta',
                  ),
                ),
              ),
            ],
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
