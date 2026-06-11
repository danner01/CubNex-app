import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import 'engagement_state.dart';

class EngagementCubit extends Cubit<EngagementState> {
  EngagementCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const EngagementState());

  final ApiClient _apiClient;

  Future<void> favoriteProduct(String productId) {
    return _favorite(tipoEntidad: 'producto', entidadId: productId);
  }

  Future<void> favoriteBusiness(String businessId) {
    return _favorite(tipoEntidad: 'negocio', entidadId: businessId);
  }

  Future<void> favoriteProperty(String propertyId) {
    return _favorite(tipoEntidad: 'propiedad', entidadId: propertyId);
  }

  Future<void> favoriteTransport(String transportId) {
    return _favorite(tipoEntidad: 'servicio', entidadId: transportId);
  }

  Future<void> loadBusinessFollowState(String businessId) async {
    final result = await _apiClient.get<List<dynamic>>(
      '/suscripciones',
      queryParameters: {'negocio_id': businessId, 'limit': 1},
      parser: (json) => json is List ? json : const [],
    );

    if (!result.isSuccess) {
      emit(state.copyWith(isFollowing: false, message: null));
      return;
    }

    emit(
      state.copyWith(
        isFollowing: (result.data ?? const []).isNotEmpty,
        message: null,
      ),
    );
  }

  Future<void> followBusiness(String businessId) async {
    emit(state.copyWith(status: EngagementStatus.loading));
    final result = await _apiClient.post<bool>(
      '/suscripciones/suscribirse/$businessId',
      data: const {'notificaciones': true},
      parser: (_) => true,
    );

    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: EngagementStatus.success,
          message: 'Te suscribiste a este negocio.',
          isFollowing: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: EngagementStatus.failure,
        message: result.error?.message ?? 'No se pudo completar la accion.',
      ),
    );
  }

  Future<void> _favorite({
    required String tipoEntidad,
    required String entidadId,
  }) async {
    emit(state.copyWith(status: EngagementStatus.loading));
    final result = await _apiClient.post<bool>(
      '/favoritos',
      data: {'tipo_entidad': tipoEntidad, 'entidad_id': entidadId},
      parser: (_) => true,
    );

    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: EngagementStatus.success,
          message: 'Guardado en favoritos.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: EngagementStatus.failure,
        message: result.error?.message ?? 'No se pudo guardar favorito.',
      ),
    );
  }
}
