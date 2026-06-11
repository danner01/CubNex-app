import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../../../config/http/api_client.dart';
import '../../data/models/map_search_item.dart';
import 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const MapState());

  final ApiClient _apiClient;

  Future<void> load({String query = ''}) async {
    final position = await _resolveCurrentPosition(silent: true);
    final userLatitude = position?.latitude ?? state.userLatitude;
    final userLongitude = position?.longitude ?? state.userLongitude;

    emit(
      state.copyWith(
        status: MapStatus.loading,
        items: const [],
        query: query,
        latitude: userLatitude,
        longitude: userLongitude,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        offset: 0,
        hasMore: true,
        clearMessage: true,
        clearRoute: true,
      ),
    );

    final result = await _apiClient.get<List<MapSearchItem>>(
      '/busqueda/mapa',
      queryParameters: {
        'limit': state.limit,
        'offset': 0,
        'lat': userLatitude,
        'lng': userLongitude,
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
      parser: _parseMapResults,
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: MapStatus.failure,
          message: result.error?.message ?? 'No se pudo cargar el mapa.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: MapStatus.success,
        items: result.data ?? const [],
        hasMore: (result.data ?? const []).length >= state.limit,
        offset: (result.data ?? const []).length,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status == MapStatus.loading) {
      return;
    }

    emit(state.copyWith(loadingMore: true, clearMessage: true));
    final result = await _apiClient.get<List<MapSearchItem>>(
      '/busqueda/mapa',
      queryParameters: {
        'limit': state.limit,
        'offset': state.offset,
        'lat': state.userLatitude,
        'lng': state.userLongitude,
        if (state.query.trim().isNotEmpty) 'q': state.query.trim(),
      },
      parser: _parseMapResults,
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          loadingMore: false,
          message:
              result.error?.message ?? 'No se pudieron cargar mas resultados.',
        ),
      );
      return;
    }

    final next = result.data ?? const [];
    emit(
      state.copyWith(
        loadingMore: false,
        items: [...state.items, ...next],
        hasMore: next.length >= state.limit,
        offset: state.offset + next.length,
      ),
    );
  }

  void filterByType(MapSearchType? type) {
    emit(
      state.copyWith(
        selectedType: type,
        clearSelectedType: type == null,
        clearMessage: true,
      ),
    );
  }

  void selectLocation(double latitude, double longitude) {
    emit(
      state.copyWith(
        latitude: latitude,
        longitude: longitude,
        clearMessage: true,
      ),
    );
  }

  Future<void> selectItem(MapSearchItem item) async {
    selectLocation(item.latitude, item.longitude);

    final fallbackRoute = [
      MapRoutePoint(
        latitude: state.userLatitude,
        longitude: state.userLongitude,
      ),
      MapRoutePoint(latitude: item.latitude, longitude: item.longitude),
    ];

    final result = await _apiClient.post<List<MapRoutePoint>>(
      '/mapbox/ruta',
      data: {
        'origen': {'lat': state.userLatitude, 'lng': state.userLongitude},
        'destino': {'lat': item.latitude, 'lng': item.longitude},
      },
      parser: _parseRoutePoints,
    );

    emit(
      state.copyWith(
        routeTargetId: item.id,
        routePoints: result.isSuccess && (result.data?.isNotEmpty ?? false)
            ? result.data
            : fallbackRoute,
        message: result.isSuccess
            ? null
            : 'No se pudo calcular la ruta exacta. Mostramos una ruta aproximada.',
        clearMessage: result.isSuccess,
      ),
    );
  }

  Future<void> useCurrentLocation() async {
    emit(state.copyWith(locating: true, clearMessage: true));
    final position = await _resolveCurrentPosition();
    if (position != null) {
      emit(
        state.copyWith(
          locating: false,
          latitude: position.latitude,
          longitude: position.longitude,
          userLatitude: position.latitude,
          userLongitude: position.longitude,
          clearRoute: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        locating: false,
        message: 'No se pudo obtener tu ubicacion.',
      ),
    );
  }

  Future<geo.Position?> _resolveCurrentPosition({bool silent = false}) async {
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent) {
          emit(state.copyWith(message: 'Activa la ubicacion del dispositivo.'));
        }
        return null;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (!silent) {
          emit(state.copyWith(message: 'Permiso de ubicacion denegado.'));
        }
        return null;
      }

      return geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      if (!silent) {
        emit(state.copyWith(message: 'No se pudo obtener tu ubicacion.'));
      }
      return null;
    }
  }

  List<MapRoutePoint> _parseRoutePoints(dynamic json) {
    if (json is! Map) return const [];
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return const [];
    final route = routes.first;
    if (route is! Map) return const [];
    final geometry = route['geometry'];
    if (geometry is! Map) return const [];
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return const [];

    return coordinates
        .whereType<List>()
        .map((point) {
          if (point.length < 2) return null;
          final longitude = double.tryParse('${point[0]}');
          final latitude = double.tryParse('${point[1]}');
          if (latitude == null || longitude == null) return null;
          return MapRoutePoint(latitude: latitude, longitude: longitude);
        })
        .whereType<MapRoutePoint>()
        .toList();
  }

  void setLocationError(String message) {
    if (!isClosed) {
      emit(state.copyWith(locating: false, message: message));
    }
  }

  List<MapSearchItem> _parseMapResults(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map(
            (item) => MapSearchItem.fromJson(
              Map<String, dynamic>.from(item),
              fallbackType: MapSearchType.business,
            ),
          )
          .toList();
    }

    if (json is Map) {
      final data = Map<String, dynamic>.from(json);
      return [
        ..._parseTypedList(data['negocios'], MapSearchType.business),
        ..._parseTypedList(data['propiedades'], MapSearchType.property),
        ..._parseTypedList(data['transporte'], MapSearchType.transport),
        ..._parseTypedList(data['resultados'], MapSearchType.business),
      ];
    }

    return const [];
  }

  List<MapSearchItem> _parseTypedList(dynamic value, MapSearchType type) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => MapSearchItem.fromJson(
            Map<String, dynamic>.from(item),
            fallbackType: type,
          ),
        )
        .toList();
  }
}
