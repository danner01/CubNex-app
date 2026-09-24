import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/environment/app_environment.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/delivery/delivery_accepted_store.dart';
import '../../data/models/delivery_activo_model.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../../data/models/delivery_profile_model.dart';
import '../../data/stores/delivery_manual_route_store.dart';
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
  static const _manualRouteColor = Color(0xFF6A1B9A);

  final ApiClient _apiClient = sl<ApiClient>();

  final List<DeliveryActivoModel> _items = [];
  Timer? _pollTimer;
  Timer? _routeDebounce;
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

  bool _manualMode = false;
  bool _saving = false;
  bool _drawingRoute = false;
  bool _locating = false;
  bool _followingDelivery = false;
  List<double>? _lastFollowedPoint;
  final List<List<double>> _manualWaypoints = [];
  List<List<double>>? _manualRouteCoords;
  _ManualRouteSummary? _manualRouteSummary;
  DeliveryProfileModel? _myProfile;

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_refresh());
      if (_followingDelivery) unawaited(_pollPosition());
    });
    unawaited(_boot());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _routeDebounce?.cancel();
    _mapboxMap?.setOnMapTapListener(null);
    super.dispose();
  }

  void _toggleManualMode(bool active) {
    setState(() {
      _manualMode = active;
      _manualRouteCoords = null;
      _manualRouteSummary = null;
    });
    final map = _mapboxMap;
    if (map != null) {
      map.setOnMapTapListener(active ? _onManualTap : null);
    }
    if (!active) _routeDebounce?.cancel();
    unawaited(_syncAll(initial: false));
    if (active && _manualWaypoints.length >= 2) _scheduleStreetRoute();
  }

  void _onManualTap(MapContentGestureContext gestureContext) {
    if (!_manualMode) return;
    if (_manualWaypoints.length >= 20) {
      _showMessage('Maximo 20 paradas por ruta.');
      return;
    }
    final coordinates = gestureContext.point.coordinates;
    setState(
      () => _manualWaypoints.add([
        coordinates.lng.toDouble(),
        coordinates.lat.toDouble(),
      ]),
    );
    _afterManualChange();
  }

  void _afterManualChange() {
    _routeDebounce?.cancel();
    setState(() {
      _manualRouteCoords = null;
      _manualRouteSummary = null;
    });
    unawaited(_syncAll(initial: false));
    _scheduleStreetRoute();
  }

  void _scheduleStreetRoute() {
    if (!_manualMode || _manualWaypoints.length < 2) return;
    _routeDebounce?.cancel();
    _routeDebounce = Timer(
      const Duration(milliseconds: 650),
      () => unawaited(_fetchStreetRoute()),
    );
  }

  void _undoWaypoint() {
    if (_manualWaypoints.isEmpty) return;
    setState(() => _manualWaypoints.removeLast());
    _afterManualChange();
  }

  Future<void> _setOriginFromCurrentLocation() async {
    final position = await _readPosition(showErrors: true);
    if (!mounted || position == null) return;
    final point = [position.longitude, position.latitude];
    setState(() {
      if (_manualWaypoints.isEmpty) {
        _manualWaypoints.add(point);
      } else {
        _manualWaypoints[0] = point;
      }
    });
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(position.longitude, position.latitude)),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 500),
    );
    _afterManualChange();
  }

  Future<void> _addPlace({
    required bool asOrigin,
    required DeliverySuggestionItem place,
  }) async {
    final point = [place.longitude, place.latitude];
    setState(() {
      if (asOrigin) {
        if (_manualWaypoints.isEmpty) {
          _manualWaypoints.add(point);
        } else {
          _manualWaypoints[0] = point;
        }
      } else {
        _manualWaypoints.add(point);
      }
    });
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(place.longitude, place.latitude),
        ),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 500),
    );
    _afterManualChange();
  }

  Future<void> _pickPlaceDialog({required bool asOrigin}) async {
    final place = await showDialog<DeliverySuggestionItem>(
      context: context,
      builder: (_) => _PlaceSearchDialog(
        title: asOrigin ? 'Buscar origen' : 'Buscar destino',
      ),
    );
    if (place == null || !mounted) return;
    await _addPlace(asOrigin: asOrigin, place: place);
  }

  void _clearWaypoints() {
    if (_manualWaypoints.isEmpty) return;
    setState(() => _manualWaypoints.clear());
    _afterManualChange();
  }

  Future<String?> _promptRouteName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Guardar ruta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre de la ruta',
            hintText: 'Ej: Entrega zona centro',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    return name;
  }

  Future<void> _saveManualRoute() async {
    if (_manualWaypoints.length < 2 || _saving) return;
    final name = await _promptRouteName();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      final routes = await DeliveryManualRouteStore.load();
      routes.add(
        DeliveryManualRoute(
          name: name,
          points: _manualWaypoints
              .map((point) => List<double>.from(point))
              .toList(),
        ),
      );
      await DeliveryManualRouteStore.save(routes);
      if (mounted) _showMessage('Ruta guardada correctamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSavedRoutes() async {
    final routes = await DeliveryManualRouteStore.load();
    if (!mounted) return;
    if (routes.isEmpty) {
      _showMessage('Aun no tienes rutas guardadas.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _SavedRoutesSheet(
        routes: routes,
        onSelect: (route) {
          setState(() {
            _manualWaypoints
              ..clear()
              ..addAll(
                route.points
                    .map((point) => List<double>.from(point))
                    .toList(),
              );
            _manualRouteCoords = null;
            _manualRouteSummary = null;
            _manualMode = true;
          });
          _mapboxMap?.setOnMapTapListener(_onManualTap);
          Navigator.of(sheetContext).pop();
          _afterManualChange();
        },
        onDelete: (route) async {
          final updated = routes.where((item) => item != route).toList();
          await DeliveryManualRouteStore.save(updated);
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
            unawaited(_openSavedRoutes());
          }
        },
      ),
    );
  }

  Future<void> _boot() async {
    final position = await _readPosition();
    if (!mounted) return;
    setState(() {
      _myLat = position?.latitude;
      _myLng = position?.longitude;
    });
    unawaited(_loadMyProfile());
    await _refresh();
  }

  Future<void> _toggleFollowing() async {
    setState(() => _followingDelivery = !_followingDelivery);
    if (_followingDelivery) {
      _lastFollowedPoint = null;
      await _centerOnDelivery();
      await _pollPosition();
      _showMessage('Seguimiento en ruta activado. Se centrara en tu posicion.');
    } else {
      _showMessage('Seguimiento detenido.');
    }
  }

  Future<void> _centerOnDelivery() async {
    final entrega = sl<DeliveryAcceptedStore>().accepted.value;
    List<double>? target;
    if (entrega?.rutaCoordenadas != null &&
        entrega!.rutaCoordenadas!.isNotEmpty) {
      target = entrega.rutaCoordenadas!.last;
    } else if (entrega?.destinoLatitude != null &&
        entrega?.destinoLongitude != null) {
      target = [entrega!.destinoLongitude!, entrega.destinoLatitude!];
    } else if (_myLat != null && _myLng != null) {
      target = [_myLng!, _myLat!];
    }
    if (target == null || !mounted) return;
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(target[0], target[1])),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _pollPosition() async {
    if (!_followingDelivery) return;
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission != geo.LocationPermission.whileInUse &&
          permission != geo.LocationPermission.always) {
        return;
      }
      final position = await geo.Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _myLat = position.latitude;
        _myLng = position.longitude;
      });
      await _followPosition();
    } catch (_) {}
  }

  Future<void> _followPosition() async {
    final map = _mapboxMap;
    if (map == null || _myLat == null || _myLng == null) return;
    final point = [_myLng!, _myLat!];
    final last = _lastFollowedPoint;
    if (last != null && _distanceMeters(last, point) < 25) return;
    _lastFollowedPoint = point;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(_myLng!, _myLat!)),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 900),
    );
  }

  double _distanceMeters(List<double> a, List<double> b) {
    const radius = 6371000.0;
    final toRad = math.pi / 180;
    final dLat = (b[1] - a[1]) * toRad;
    final dLng = (b[0] - a[0]) * toRad;
    final lat1 = a[1] * toRad;
    final lat2 = b[1] * toRad;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * radius * math.asin(math.sqrt(h.toDouble()));
  }

  Future<void> _loadMyProfile() async {
    final result = await _apiClient.get<List<DeliveryProfileModel>>(
      '/delivery-perfiles',
      parser: (json) {
        if (json is! List) return const <DeliveryProfileModel>[];
        return json
            .whereType<Map>()
            .map(
              (item) => DeliveryProfileModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      },
    );
    if (!mounted) return;
    if (result.isSuccess && (result.data?.isNotEmpty ?? false)) {
      setState(() => _myProfile = result.data!.first);
    }
  }

  Color _ownMarkerColor() {
    final custom = _myProfile?.colorMarcador == null
        ? null
        : parseDeliveryMarkerColor(_myProfile!.colorMarcador);
    return custom ?? _myMarkerColor;
  }

  Future<geo.Position?> _readPosition({bool showErrors = false}) async {
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (showErrors) {
          _showMessage('Activa la ubicacion del dispositivo e intenta de nuevo.');
        }
        return null;
      }
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.deniedForever) {
        if (showErrors) await _offerSettingsPrompt();
        return null;
      }
      if (permission == geo.LocationPermission.denied) {
        if (showErrors) {
          _showMessage(
            'Permiso de ubicacion denegado. Concedelo desde los ajustes e intenta de nuevo.',
          );
        }
        return null;
      }
      try {
        return await geo.Geolocator.getCurrentPosition(
          locationSettings: geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            timeLimit: const Duration(seconds: 20),
          ),
        );
      } catch (_) {
        try {
          final last = await geo.Geolocator.getLastKnownPosition();
          if (last != null) return last;
        } catch (_) {}
        if (showErrors) {
          _showMessage(
            'No se pudo obtener tu posicion. Estate en un lugar abierto (GPS) e intenta de nuevo.',
          );
        }
        return null;
      }
    } catch (_) {
      if (showErrors) {
        _showMessage(
          'No se pudo acceder a la ubicacion. Revisa los permisos e intenta de nuevo.',
        );
      }
      return null;
    }
  }

  Future<void> _offerSettingsPrompt() async {
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubicacion bloqueada'),
        content: const Text(
          'La app necesita acceso a tu ubicacion. Permitela desde los ajustes del sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    if (open == true) {
      try {
        await geo.Geolocator.openAppSettings();
      } catch (_) {}
    }
  }

  Future<void> _locateCurrentPosition() async {
    if (_locating) return;
    setState(() => _locating = true);
    final position = await _readPosition(showErrors: true);
    if (!mounted) {
      return;
    }
    if (position == null) {
      setState(() => _locating = false);
      return;
    }
    setState(() {
      _myLat = position.latitude;
      _myLng = position.longitude;
      _locating = false;
    });
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 600),
    );
    unawaited(_refresh());
  }

  void _onFocusLocation(double lat, double lng) {
    if (!mounted) return;
    setState(() {
      _myLat = lat;
      _myLng = lng;
    });
    unawaited(_refresh());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _fetchStreetRoute() async {
    if (!_manualMode || _manualWaypoints.length < 2) return;
    final waypoints = _manualWaypoints;
    setState(() => _drawingRoute = true);
    final data = <String, dynamic>{
      'origen': {'lat': waypoints.first[1], 'lng': waypoints.first[0]},
      'destino': {'lat': waypoints.last[1], 'lng': waypoints.last[0]},
      if (waypoints.length > 2)
        'intermedios': [
          for (var i = 1; i < waypoints.length - 1; i++)
            {'lat': waypoints[i][1], 'lng': waypoints[i][0]},
        ],
    };
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/mapbox/ruta',
      data: data,
      parser: (json) =>
          json is Map ? Map<String, dynamic>.from(json) : const {},
    );
    if (!mounted) return;
    if (result.isSuccess && _manualWaypoints.length >= 2) {
      final routes = result.data?['routes'];
      if (routes is List && routes.isNotEmpty) {
        final firstRoute = routes[0];
        if (firstRoute is Map) {
          final geometry = firstRoute['geometry'];
          final coords = geometry is Map ? geometry['coordinates'] : null;
          if (coords is List && coords.length >= 2) {
            final parsed = <List<double>>[];
            for (final entry in coords) {
              if (entry is List && entry.length >= 2) {
                parsed.add([_toNum(entry[0]), _toNum(entry[1])]);
              }
            }
            if (parsed.length >= 2) {
              setState(() {
                _drawingRoute = false;
                _manualRouteCoords = parsed;
                _manualRouteSummary = _ManualRouteSummary(
                  distanceMeters: _toNum(firstRoute['distance']),
                  durationSeconds: _toNum(firstRoute['duration']),
                );
              });
              await _syncAll(initial: false);
              return;
            }
          }
        }
      }
    }
    setState(() {
      _drawingRoute = false;
      _manualRouteCoords = null;
      _manualRouteSummary = null;
    });
    _showMessage(
      'No se pudo calcular la ruta por calles. Se muestra la linea recta.',
    );
    await _syncAll(initial: false);
  }

  double _toNum(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    if (mounted) setState(() {});
    _routeManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _pointManager?.setIconAllowOverlap(true);
    _pointManager?.setTextAllowOverlap(true);
    if (_manualMode) {
      mapboxMap.setOnMapTapListener(_onManualTap);
    }
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
      final myColor = _ownMarkerColor();
      final myIconId = await ensureDeliveryMarkerIcon(
        _mapboxMap!,
        myColor,
        _myProfile?.vehicleType,
      );
      final fallbackIconId = myIconId == null
          ? await ensureDeliveryPinIcon(
              _mapboxMap!,
              myColor,
              keyPrefix: 'del_self_fallback',
            )
          : null;
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(_myLng!, _myLat!)),
          iconImage: fallbackIconId ?? myIconId ?? 'marker',
          iconColor: fallbackIconId == null && myIconId == null
              ? myColor.toARGB32()
              : null,
          iconSize: 1.4,
          iconAnchor: IconAnchor.BOTTOM,
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
      final color = _markerColor(item, i);
      final iconId = await ensureDeliveryMarkerIcon(
        _mapboxMap!,
        color,
        item.tipoVehiculo,
      );
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconImage: iconId ?? 'marker',
          iconColor: iconId == null ? color.toARGB32() : null,
          iconSize: 1.15,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    final entrega = sl<DeliveryAcceptedStore>().accepted.value;
    if (_manualMode && _manualWaypoints.isNotEmpty) {
      await _drawManualRoute(pointManager);
    } else if (entrega != null) {
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
        await _addMarker(route.first, AppColorsForRoute.origin, label: 'Origen');
        await _addMarker(
          route.last,
          AppColorsForRoute.destination,
          label: 'Destino',
        );
        track(route.first[1], route.first[0]);
        track(route.last[1], route.last[0]);
      } else if (route != null && route.isNotEmpty) {
        await _addMarker(route.first, AppColorsForRoute.origin, label: 'Origen');
        track(route.first[1], route.first[0]);
      } else if (entrega.negocioLongitude != null &&
          entrega.negocioLatitude != null) {
        await _addMarker(
          [entrega.negocioLongitude!, entrega.negocioLatitude!],
          AppColorsForRoute.origin,
          label: 'Origen',
        );
        track(entrega.negocioLatitude!, entrega.negocioLongitude!);
      }
    }

    if (!initial || _didInitialCamera) return;
    _didInitialCamera = true;

    if (_manualMode && _manualWaypoints.length >= 2) {
      final center = _bboxCenter(_manualWaypoints);
      if (center != null) {
        await _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(center[0], center[1])),
            zoom: _zoomFor(_manualWaypoints),
          ),
          MapAnimationOptions(duration: 400),
        );
        return;
      }
    }

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
            coordinates: Position(
              (minLng + maxLng) / 2,
              (minLat + maxLat) / 2,
            ),
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

  Future<void> _drawManualRoute(PointAnnotationManager pointManager) async {
    final coords = _manualRouteCoords;
    if (coords != null && coords.length >= 2) {
      await _routeManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: coords
                .map((point) => Position(point[0], point[1]))
                .toList(),
          ),
          lineColor: _manualRouteColor.toARGB32(),
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1.4,
          lineWidth: 5,
          lineOpacity: 0.92,
        ),
      );
    } else if (_manualWaypoints.length >= 2) {
      await _routeManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: _manualWaypoints
                .map((point) => Position(point[0], point[1]))
                .toList(),
          ),
          lineColor: _manualRouteColor.toARGB32(),
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1,
          lineWidth: 4,
          lineOpacity: 0.85,
        ),
      );
    }

    for (var i = 0; i < _manualWaypoints.length; i++) {
      final point = _manualWaypoints[i];
      final isOrigin = i == 0;
      final isDestination = i == _manualWaypoints.length - 1 && i != 0;
      final color = isOrigin
          ? AppColorsForRoute.origin
          : isDestination
          ? AppColorsForRoute.destination
          : const Color(0xFF00897B);
      final innerLabel = isOrigin || isDestination ? null : '${i + 1}';
      final icon = await ensureDeliveryPinIcon(
        _mapboxMap!,
        color,
        keyPrefix: 'del_stop_pin',
        label: innerLabel,
      );
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(point[0], point[1])),
          iconImage: icon ?? 'marker',
          iconColor: icon == null ? color.toARGB32() : null,
          iconSize: 0.95,
          iconAnchor: IconAnchor.BOTTOM,
          textField: isOrigin || isDestination
              ? (isOrigin ? 'Origen' : 'Destino')
              : null,
          textColor: Colors.white.toARGB32(),
          textSize: 11,
          textHaloColor: const Color(0xFF212121).toARGB32(),
          textHaloWidth: 1.6,
        ),
      );
    }
  }

  Future<void> _addMarker(
    List<double> point,
    Color color, {
    String? label,
  }) async {
    final manager = _pointManager;
    if (manager == null) return;
    final icon = await ensureDeliveryPinIcon(
      _mapboxMap!,
      color,
      keyPrefix: 'del_route_pin',
    );
    await manager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(point[0], point[1])),
        iconImage: icon ?? 'marker',
        iconColor: icon == null ? color.toARGB32() : null,
        iconSize: 1.0,
        iconAnchor: IconAnchor.BOTTOM,
        textField: label,
        textColor: Colors.white.toARGB32(),
        textSize: 11,
        textHaloColor: const Color(0xFF212121).toARGB32(),
        textHaloWidth: 1.6,
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
          final myColor = _ownMarkerColor();
          final manualActive = _manualMode && _manualWaypoints.isNotEmpty;

          final routeChips = <String>[];
          if (manualActive && _manualWaypoints.length >= 2) {
            if (_drawingRoute) {
              routeChips.add('Calculando ruta por calles...');
            } else if (_manualRouteSummary != null) {
              routeChips
                ..add(_formatDistance(_manualRouteSummary!.distanceMeters / 1000))
                ..add(_formatMinutes(_manualRouteSummary!.durationSeconds / 60));
            } else {
              routeChips.add('Toca "Dibujar ruta por calles"');
            }
          }

          return Stack(
            children: [
              Positioned.fill(
                child: MapWidget(
                  // ignore: deprecated_member_use
                  cameraOptions: CameraOptions(center: mapCenter, zoom: 12),
                  onMapCreated: _onMapCreated,
                ),
              ),
              if (_mapboxMap != null)
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: DeliveryMapSearchOverlay(
                      mapboxMap: _mapboxMap!,
                      label: 'Buscar direccion en el mapa...',
                      onFocusLocation: _onFocusLocation,
                      onUseCurrentLocation: _locateCurrentPosition,
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
                      heroTag: 'delivery_route_locate',
                      tooltip: 'Mi ubicacion',
                      onPressed: _locating
                          ? null
                          : () => unawaited(_locateCurrentPosition()),
                      child: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ),
              ),
              if (entrega != null)
                Positioned(
                  top: 0,
                  right: 12,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 76),
                      child: FloatingActionButton.small(
                        heroTag: 'delivery_route_enruta',
                        tooltip: _followingDelivery
                            ? 'Detener seguimiento'
                            : 'En ruta',
                        backgroundColor: _followingDelivery
                            ? theme.colorScheme.primary
                            : null,
                        foregroundColor: _followingDelivery
                            ? theme.colorScheme.onPrimary
                            : null,
                        onPressed: () => unawaited(_toggleFollowing()),
                        child: Icon(
                          _followingDelivery
                              ? Icons.location_disabled_rounded
                              : Icons.route_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_manualMode)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 90),
                        child: _ManualStatusBanner(
                          waypoints: _manualWaypoints.length,
                          drawing: _drawingRoute,
                          routeReady: _manualRouteCoords != null,
                          onClear: _manualWaypoints.isEmpty
                              ? null
                              : _clearWaypoints,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: DraggableScrollableSheet(
                  initialChildSize: _manualMode ? 0.32 : 0.27,
                  minChildSize: 0.22,
                  maxChildSize: 0.8,
                  snap: true,
                  snapSizes: const [0.22, 0.32, 0.55, 0.8],
                  builder: (context, sheetController) => _SheetPanel(
                    controller: sheetController,
                    child: ListView(
                      controller: sheetController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ruta y mapa',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _manualWaypoints.isEmpty
                                  ? null
                                  : _clearWaypoints,
                              tooltip: 'Limpiar ruta manual',
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasRouteOverlay
                              ? 'Entrega aceptada y ruta hacia el cliente.'
                              : 'Mapa en tiempo real: tu posicion y los repartidores activos.',
                        ),
                        const SizedBox(height: 14),
                        _MapLegendRow(
                          myColor: myColor,
                          showAcceptRoute: hasRouteOverlay,
                          showManualRoute: manualActive,
                        ),
                        const SizedBox(height: 12),
                        if (_myLat == null) ...[
                          _LocatePrompt(
                            locating: _locating,
                            onRetry: () =>
                                unawaited(_locateCurrentPosition()),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _ManualRouteControls(
                          active: _manualMode,
                          waypoints: _manualWaypoints.length,
                          saving: _saving,
                          drawing: _drawingRoute,
                          routeChips: routeChips,
                          onToggle: _toggleManualMode,
                          onUndo: _manualWaypoints.isEmpty ? null : _undoWaypoint,
                          onClear: _manualWaypoints.isEmpty ? null : _clearWaypoints,
                          onSave: _manualWaypoints.length < 2 ? null : _saveManualRoute,
                          onDrawRoute: _manualWaypoints.length < 2
                              ? null
                              : () => unawaited(_fetchStreetRoute()),
                          onOpenRoutes: _openSavedRoutes,
                          onSetOriginLocation: _setOriginFromCurrentLocation,
                          onSearchOrigin: () =>
                              unawaited(_pickPlaceDialog(asOrigin: true)),
                          onSearchDestination: () =>
                              unawaited(_pickPlaceDialog(asOrigin: false)),
                        ),
                        const Divider(height: 28),
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
                              ? 'Tu posicion no se ha detectado aun. Usa el boton de ubicacion del mapa.'
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
                        if (routeInfoAvailable) ...[
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _ActiveDeliveryCard(item: _items[index]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ManualRouteSummary {
  const _ManualRouteSummary({
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final double distanceMeters;
  final double durationSeconds;
}

class _SheetPanel extends StatelessWidget {
  const _SheetPanel({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _ManualStatusBanner extends StatelessWidget {
  const _ManualStatusBanner({
    required this.waypoints,
    required this.drawing,
    required this.routeReady,
    required this.onClear,
  });

  final int waypoints;
  final bool drawing;
  final bool routeReady;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final String main;
    final String sub;
    if (waypoints == 0) {
      main = 'Paso 1 de 2 — fija el ORIGEN';
      sub = 'Toca el mapa, busca una direccion o usa "Mi ubicacion" como origen.';
    } else if (waypoints == 1) {
      main = 'Paso 2 de 2 — fija el DESTINO';
      sub = 'Toca el mapa o busca la direccion de entrega.';
    } else {
      main = '$waypoints paradas';
      sub = drawing
          ? 'Calculando la ruta por las calles...'
          : routeReady
          ? 'Ruta por calles lista. Revisa distancia y tiempo en el panel.'
          : 'Toca el mapa para anadir paradas y luego "Dibujar ruta por calles".';
    }

    return Material(
      color: const Color(0xEE212121),
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.edit_road_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    main,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                tooltip: 'Limpiar ruta',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.white70,
              ),
          ],
        ),
      ),
    );
  }
}

class _LocatePrompt extends StatelessWidget {
  const _LocatePrompt({required this.locating, required this.onRetry});

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
                    'Activa el GPS y toca el boton para centrar el mapa en ti.',
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

class _MapLegendRow extends StatelessWidget {
  const _MapLegendRow({
    required this.myColor,
    required this.showAcceptRoute,
    required this.showManualRoute,
  });

  final Color myColor;
  final bool showAcceptRoute;
  final bool showManualRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[
      _legendItem(
        theme,
        myColor,
        'Tu',
        labelColor: readableDeliveryMarkerIconColor(myColor),
      ),
      _legendItem(theme, const Color(0xFF3949AB), 'Repartidor'),
      if (showAcceptRoute) ...[
        _legendItem(theme, AppColorsForRoute.origin, 'Origen'),
        _legendItem(theme, AppColorsForRoute.destination, 'Destino'),
        _legendItem(theme, Colors.blue, 'Ruta', line: true),
      ],
      if (showManualRoute)
        _legendItem(
          theme,
          const Color(0xFF6A1B9A),
          'Ruta manual',
          line: true,
        ),
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

class _ManualRouteControls extends StatelessWidget {
  const _ManualRouteControls({
    required this.active,
    required this.waypoints,
    required this.saving,
    required this.drawing,
    required this.routeChips,
    required this.onToggle,
    required this.onUndo,
    required this.onClear,
    required this.onSave,
    required this.onOpenRoutes,
    required this.onDrawRoute,
    required this.onSetOriginLocation,
    required this.onSearchOrigin,
    required this.onSearchDestination,
  });

  final bool active;
  final int waypoints;
  final bool saving;
  final bool drawing;
  final List<String> routeChips;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback? onSave;
  final VoidCallback onOpenRoutes;
  final VoidCallback? onDrawRoute;
  final VoidCallback onSetOriginLocation;
  final VoidCallback onSearchOrigin;
  final VoidCallback onSearchDestination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilterChip(
              selected: active,
              avatar: Icon(
                Icons.edit_road_rounded,
                size: 18,
                color: active ? Colors.white : theme.colorScheme.secondary,
              ),
              label: const Text('Ruta manual'),
              labelStyle: TextStyle(
                color: active ? Colors.white : null,
                fontWeight: FontWeight.w800,
              ),
              selectedColor: theme.colorScheme.secondary,
              checkmarkColor: Colors.white,
              onSelected: onToggle,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onOpenRoutes,
              icon: const Icon(Icons.bookmarks_outlined, size: 18),
              label: const Text('Mis rutas'),
            ),
          ],
        ),
        if (active) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                theme,
                Icons.my_location_rounded,
                'Origen: mi ubicacion',
                onSetOriginLocation,
                highlight: true,
              ),
              _actionButton(
                theme,
                Icons.place_outlined,
                'Origen por direccion',
                onSearchOrigin,
              ),
              _actionButton(
                theme,
                Icons.flag_outlined,
                'Destino por direccion',
                onSearchDestination,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                theme,
                Icons.route_rounded,
                drawing ? 'Calculando...' : 'Dibujar ruta por calles',
                drawing ? null : onDrawRoute,
                highlight: true,
              ),
              _actionButton(
                theme,
                Icons.undo_rounded,
                'Deshacer',
                onUndo,
              ),
              _actionButton(
                theme,
                Icons.delete_outline_rounded,
                'Limpiar',
                onClear,
              ),
              _actionButton(
                theme,
                Icons.save_outlined,
                saving ? 'Guardando...' : 'Guardar',
                onSave,
                highlight: true,
              ),
            ],
          ),
          if (routeChips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in routeChips)
                  _routeChip(theme, chip),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            waypoints == 0
                ? 'Primer toque en el mapa: ORIGEN (pin verde).'
                : waypoints == 1
                ? 'Un punto fijado. El segundo toque (o busqueda) sera el DESTINO (pin rojo).'
                : '$waypoints paradas: la primera es el origen y la ultima el destino. Toca el mapa para anadir paradas intermedias.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _routeChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.route_outlined,
            size: 14,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    ThemeData theme,
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    bool highlight = false,
  }) {
    final color = highlight
        ? theme.colorScheme.secondary.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHighest;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: onPressed == null
                    ? theme.disabledColor
                    : theme.colorScheme.secondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: onPressed == null
                      ? theme.disabledColor
                      : theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedRoutesSheet extends StatelessWidget {
  const _SavedRoutesSheet({
    required this.routes,
    required this.onSelect,
    required this.onDelete,
  });

  final List<DeliveryManualRoute> routes;
  final ValueChanged<DeliveryManualRoute> onSelect;
  final ValueChanged<DeliveryManualRoute> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Mis rutas',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: routes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final stops = route.points.length;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.secondary
                          .withValues(alpha: 0.12),
                      child: Icon(
                        Icons.route_rounded,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    title: Text(
                      route.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      stops == 1 ? '1 parada' : '$stops paradas',
                    ),
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => onDelete(route),
                    ),
                    onTap: () => onSelect(route),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog({required this.title});

  final String title;

  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  final ApiClient _apiClient = sl<ApiClient>();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<DeliverySuggestionItem> _suggestions = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(trimmed);
    });
  }

  Future<void> _search(String query) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      '/mapbox/geocodificar',
      queryParameters: {'direccion': '$query, Cuba'},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      if (result.isSuccess) {
        _suggestions = _parseSuggestions(result.data);
      } else {
        _suggestions = const [];
      }
    });
  }

  List<DeliverySuggestionItem> _parseSuggestions(Map<String, dynamic>? data) {
    final raw = data?['features'] ?? data?['resultados'] ?? data?['lugares'];
    if (raw is! List) return const [];
    final items = <DeliverySuggestionItem>[];
    for (final entry in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final label =
          map['place_name'] ??
          map['placeName'] ??
          map['direccion'] ??
          map['nombre'] ??
          map['text'];
      if (label is! String || label.trim().isEmpty) continue;

      double? lat;
      double? lng;
      final center = map['center'];
      if (center is List && center.length >= 2) {
        lng = _toDouble(center[0]);
        lat = _toDouble(center[1]);
      }
      final geometry = map['geometry'];
      if (geometry is Map && geometry['coordinates'] is List) {
        final coordinates = geometry['coordinates'] as List;
        if (coordinates.length >= 2) {
          lng = _toDouble(coordinates[0]);
          lat = _toDouble(coordinates[1]);
        }
      }
      if (lat == null || lng == null) continue;
      items.add(
        DeliverySuggestionItem(
          label: label.trim(),
          latitude: lat,
          longitude: lng,
        ),
      );
      if (items.length >= 5) break;
    }
    return items;
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _suggestions;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Direccion o lugar...',
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (results.isNotEmpty) {
                  Navigator.of(context).pop(results.first);
                }
              },
            ),
            const SizedBox(height: 8),
            if (results.isEmpty && !_searching)
              const SizedBox(height: 8)
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = results[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 20),
                      title: Text(
                        suggestion.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () => Navigator.of(context).pop(suggestion),
                    );
                  },
                ),
              ),
            if (results.isEmpty && !_searching)
              Text(
                _controller.text.trim().isEmpty
                    ? 'Escribe una direccion para buscar.'
                    : 'Sin resultados. Escribe mas detalle.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}