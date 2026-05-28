import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/promotion_model.dart';
import 'promotions_state.dart';

class PromotionsCubit extends Cubit<PromotionsState> {
  PromotionsCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const PromotionsState());

  final ApiClient _apiClient;

  Future<void> loadPublic() async {
    emit(state.copyWith(status: PromotionsStatus.loading));
    await _load('/promociones');
  }

  Future<void> loadMine() async {
    emit(state.copyWith(status: PromotionsStatus.loading));
    final businessResult = await _apiClient.get<BusinessModel?>(
      '/negocios/mi-negocio',
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return BusinessModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        return null;
      },
    );
    final businessId = businessResult.data?.id;
    if (!businessResult.isSuccess || businessId == null) {
      emit(
        state.copyWith(
          status: PromotionsStatus.failure,
          message: businessResult.error?.message ?? 'No tienes negocio creado.',
        ),
      );
      return;
    }

    emit(state.copyWith(businessId: businessId));
    await _load('/promociones/mis-promociones');
  }

  Future<void> create({
    required String title,
    required String type,
    String? description,
    int? percent,
    double? value,
    String? code,
  }) async {
    final businessId = state.businessId;
    if (businessId == null) return;

    emit(state.copyWith(status: PromotionsStatus.saving));
    final now = DateTime.now();
    final result = await _apiClient.post<void>(
      '/promociones',
      data: {
        'negocio_id': businessId,
        'tipo': type,
        'titulo': title,
        'descripcion': description,
        'codigo': code,
        'porcentaje': percent,
        'valor': value,
        'fecha_inicio': now.toIso8601String(),
        'fecha_fin': now.add(const Duration(days: 30)).toIso8601String(),
        'activo': true,
      },
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PromotionsStatus.failure,
          message: result.error?.message ?? 'No se pudo crear la promocion.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PromotionsStatus.success,
        message: 'Promocion creada.',
      ),
    );
    await loadMine();
  }

  Future<void> participate(String promotionId) async {
    emit(state.copyWith(status: PromotionsStatus.saving));
    final result = await _apiClient.post<void>(
      '/promociones/$promotionId/participar',
      data: const {},
      parser: (_) {},
    );
    emit(
      state.copyWith(
        status: result.isSuccess ? PromotionsStatus.success : PromotionsStatus.failure,
        message: result.isSuccess
            ? 'Participacion registrada.'
            : result.error?.message ?? 'No se pudo participar.',
      ),
    );
  }

  Future<void> redeem(String promotionId, {String? code}) async {
    emit(state.copyWith(status: PromotionsStatus.saving));
    final result = await _apiClient.post<void>(
      '/promociones/$promotionId/canjear',
      data: {'codigo': code},
      parser: (_) {},
    );
    emit(
      state.copyWith(
        status: result.isSuccess ? PromotionsStatus.success : PromotionsStatus.failure,
        message: result.isSuccess
            ? 'Promocion canjeada.'
            : result.error?.message ?? 'No se pudo canjear.',
      ),
    );
  }

  Future<void> _load(String path) async {
    final result = await _apiClient.get<List<PromotionModel>>(
      path,
      queryParameters: {'limit': 80, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    PromotionModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PromotionsStatus.failure,
          message: result.error?.message ?? 'No se pudieron cargar promociones.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PromotionsStatus.success,
        items: result.data ?? const [],
      ),
    );
  }
}
