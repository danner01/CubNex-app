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
    emit(
      state.copyWith(
        status: MapStatus.loading,
        query: query,
        clearMessage: true,
      ),
    );

    final result = await _apiClient.get<List<MapSearchItem>>(
      '/busqueda/mapa',
      queryParameters: {
        'limit': 80,
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

  Future<void> useCurrentLocation() async {
    emit(state.copyWith(locating: true, clearMessage: true));
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        emit(
          state.copyWith(
            locating: false,
            message: 'Activa la ubicacion del dispositivo.',
          ),
        );
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        emit(
          state.copyWith(
            locating: false,
            message: 'Permiso de ubicacion denegado.',
          ),
        );
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition();
      emit(
        state.copyWith(
          locating: false,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          locating: false,
          message: 'No se pudo obtener tu ubicacion.',
        ),
      );
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
