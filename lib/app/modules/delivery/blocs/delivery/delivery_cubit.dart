import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../../data/models/delivery_profile_model.dart';
import 'delivery_accepted_store.dart';
import 'delivery_state.dart';

class DeliveryCubit extends Cubit<DeliveryState> {
  DeliveryCubit({
    required ApiClient apiClient,
    required DeliveryAcceptedStore acceptedStore,
  }) : _apiClient = apiClient,
       _acceptedStore = acceptedStore,
       super(const DeliveryState());

  final ApiClient _apiClient;
  final DeliveryAcceptedStore _acceptedStore;
  bool _queueRequestInFlight = false;

  Future<void> load() async {
    if (state.status == DeliveryStatus.loading) return;
    emit(
      state.copyWith(
        status: DeliveryStatus.loading,
        errorMessage: null,
        queueError: null,
      ),
    );
    final result = await _apiClient.get<List<DeliveryProfileModel>>(
      '/delivery-perfiles',
      parser: (json) => _asList(json, DeliveryProfileModel.fromJson),
    );
    if (isClosed) return;

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: DeliveryStatus.failure,
          errorMessage:
              result.error?.message ?? 'No se pudo cargar tu perfil delivery.',
        ),
      );
      return;
    }
    final items = result.data ?? const <DeliveryProfileModel>[];
    final profile = items.isEmpty ? null : items.first;
    emit(
      state.copyWith(
        status: DeliveryStatus.ready,
        profile: profile,
        errorMessage: null,
      ),
    );
    if (profile != null && profile.active) {
      await loadDisponibles(silent: true);
    }
  }

  Future<void> setDisponible(
    bool value, {
    double? latitude,
    double? longitude,
  }) async {
    final profile = state.profile;
    if (profile == null) return;
    emit(state.copyWith(isUpdatingProfile: true, queueError: null));

    if (value) {
      final locationResult = await _apiClient.post<Map<String, dynamic>>(
        '/delivery-ubicaciones',
        data: {
          'delivery_id': profile.id,
          'coordenadas': {'lat': latitude, 'lng': longitude},
        },
        parser: (json) => json is Map
            ? Map<String, dynamic>.from(json)
            : const <String, dynamic>{},
      );
      if (isClosed) return;
      if (!locationResult.isSuccess) {
        emit(
          state.copyWith(
            isUpdatingProfile: false,
            queueError:
                locationResult.error?.message ??
                'No se pudo reportar tu ubicacion.',
          ),
        );
        return;
      }
    }

    final updateResult = await _apiClient.put<void>(
      '/delivery-perfiles/${profile.id}',
      data: {'disponible': value},
      parser: (_) {},
    );
    if (isClosed) return;
    if (!updateResult.isSuccess) {
      emit(
        state.copyWith(
          isUpdatingProfile: false,
          queueError:
              updateResult.error?.message ??
              'No se pudo actualizar tu disponibilidad.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isUpdatingProfile: false,
        profile: profile.copyWith(available: value),
      ),
    );
    if (value) {
      await loadDisponibles(silent: true);
    } else {
      emit(
        state.copyWith(
          availableEntregas: const [],
          errorMessage: null,
          queueError: null,
        ),
      );
    }
  }

  Future<void> reportLocation({
    required double latitude,
    required double longitude,
  }) async {
    final profile = state.profile;
    if (profile == null) return;
    await _apiClient.post<Map<String, dynamic>>(
      '/delivery-ubicaciones',
      data: {
        'delivery_id': profile.id,
        'coordenadas': {'lat': latitude, 'lng': longitude},
      },
      parser: (json) => json is Map
          ? Map<String, dynamic>.from(json)
          : const <String, dynamic>{},
    );
  }

  Future<void> loadDisponibles({bool silent = false}) async {
    final profile = state.profile;
    if (profile == null || !profile.available) return;
    if (_queueRequestInFlight) return;
    _queueRequestInFlight = true;
    if (!silent) emit(state.copyWith(refreshingQueue: true));

    final result = await _apiClient.get<List<DeliveryEntregaModel>>(
      '/entregas/disponibles',
      parser: (json) => _asList(json, DeliveryEntregaModel.fromJson),
    );
    _queueRequestInFlight = false;
    if (isClosed) return;

    if (result.isSuccess) {
      emit(
        state.copyWith(
          refreshingQueue: false,
          availableEntregas: result.data ?? const <DeliveryEntregaModel>[],
          errorMessage: null,
          queueError: null,
        ),
      );
    } else {
      emit(
        state.copyWith(
          refreshingQueue: false,
          queueError:
              result.error?.message ?? 'No se pudo cargar la cola de entregas.',
        ),
      );
    }
  }

  Future<void> aceptar(String entregaId) async {
    if (state.acceptingEntregaId != null) return;
    emit(state.copyWith(acceptingEntregaId: entregaId, queueError: null));

    final result = await _apiClient.post<DeliveryEntregaModel>(
      '/entregas/$entregaId/aceptar',
      parser: (json) =>
          DeliveryEntregaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (isClosed) return;

    if (result.isSuccess) {
      final entrega = result.data;
      if (entrega != null) {
        _acceptedStore.accept(entrega);
      }
      emit(
        state.copyWith(
          acceptingEntregaId: null,
          availableEntregas: state.availableEntregas
              .where((item) => item.id != entregaId)
              .toList(),
          acceptedEntrega: entrega,
          errorMessage: null,
          queueError: null,
        ),
      );
      return;
    }

    if (result.error?.code == 'ENTREGA_NO_DISPONIBLE') {
      await loadDisponibles(silent: true);
      emit(
        state.copyWith(
          acceptingEntregaId: null,
          queueError: result.error?.message ?? 'Esta entrega ya fue asignada.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        acceptingEntregaId: null,
        queueError: result.error?.message ?? 'No se pudo aceptar la entrega.',
      ),
    );
  }

  void clearAcceptedEntrega() {
    emit(state.copyWith(acceptedEntrega: null));
  }

  List<T> _asList<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    if (json is Map) {
      final raw = json['items'] ?? json['datos'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }
    return const [];
  }
}
