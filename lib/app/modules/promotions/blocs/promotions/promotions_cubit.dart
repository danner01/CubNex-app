import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/promotion_model.dart';
import 'promotions_state.dart';

class PromotionsCubit extends Cubit<PromotionsState> {
  PromotionsCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const PromotionsState());

  final ApiClient _apiClient;
  static const _loadTimeout = Duration(seconds: 12);

  Future<void> loadPublic() async {
    emit(state.copyWith(status: PromotionsStatus.loading));
    await _load('/promociones');
  }

  Future<void> loadMine() async {
    emit(state.copyWith(status: PromotionsStatus.loading));
    final businessResult = await _apiClient
        .get<BusinessModel?>(
          '/negocios/mi-negocio',
          parser: (json) {
            if (json is List && json.isNotEmpty) {
              return BusinessModel.fromJson(
                Map<String, dynamic>.from(json.first as Map),
              );
            }
            return null;
          },
        )
        .timeout(
          _loadTimeout,
          onTimeout: () => const ApiResult.failure(
            ApiFailure(
              code: 'BUSINESS_TIMEOUT',
              message: 'No se pudo confirmar tu negocio activo a tiempo.',
            ),
          ),
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
    await _load('/promociones/mis-promociones', businessId: businessId);
  }

  Future<void> loadForBusiness(String businessId) async {
    emit(
      state.copyWith(status: PromotionsStatus.loading, businessId: businessId),
    );
    await _load('/promociones/mis-promociones', businessId: businessId);
  }

  Future<void> create({
    required String title,
    required String type,
    required DateTime startAt,
    required DateTime endAt,
    String? description,
    int? percent,
    double? value,
    String? code,
    List<String>? productIds,
  }) async {
    final businessId = state.businessId;
    if (businessId == null) return;

    emit(state.copyWith(status: PromotionsStatus.saving));
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
        'productos_aplicables': productIds ?? const <String>[],
        'fecha_inicio': startAt.toIso8601String(),
        'fecha_fin': endAt.toIso8601String(),
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
    await loadForBusiness(businessId);
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
        status: result.isSuccess
            ? PromotionsStatus.success
            : PromotionsStatus.failure,
        message: result.isSuccess
            ? 'Participacion registrada.'
            : result.error?.message ?? 'No se pudo participar.',
      ),
    );
  }

  Future<void> redeem(String promotionId, {String? code}) async {
    emit(state.copyWith(status: PromotionsStatus.saving));
    final result = await _apiClient.post<PromotionRedemption?>(
      '/promociones/$promotionId/canjear',
      data: {'codigo': code},
      parser: (json) {
        if (json is Map && json['canje'] is Map) {
          return PromotionRedemption.fromJson(
            Map<String, dynamic>.from(json['canje'] as Map),
          );
        }
        return null;
      },
    );
    emit(
      state.copyWith(
        status: result.isSuccess
            ? PromotionsStatus.success
            : PromotionsStatus.failure,
        message: result.isSuccess
            ? 'QR de canje generado.'
            : result.error?.message ?? 'No se pudo canjear.',
        redemption: result.data,
      ),
    );
  }

  Future<void> validateRedemption(String token) async {
    emit(state.copyWith(status: PromotionsStatus.saving));
    final result = await _apiClient.post<Map<String, dynamic>?>(
      '/promociones/validar-canje',
      data: {'token': token},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : null,
    );
    emit(
      state.copyWith(
        status: result.isSuccess
            ? PromotionsStatus.success
            : PromotionsStatus.failure,
        message: result.isSuccess
            ? _validatedMessage(result.data)
            : result.error?.message ?? 'No se pudo validar el canje.',
      ),
    );
    final businessId = state.businessId;
    if (result.isSuccess && businessId != null) {
      await loadForBusiness(businessId);
    }
  }

  void clearRedemption() {
    emit(state.copyWith(clearRedemption: true));
  }

  String _validatedMessage(Map<String, dynamic>? data) {
    final cliente = data?['cliente'];
    final promocion = data?['promocion'];
    final clientName = cliente is Map
        ? cliente['nombre_completo']?.toString()
        : null;
    final title = promocion is Map ? promocion['titulo']?.toString() : null;
    return [
      'Promocion validada',
      if (title != null && title.isNotEmpty) title,
      if (clientName != null && clientName.isNotEmpty) 'Cliente: $clientName',
    ].join(' · ');
  }

  Future<void> _load(String path, {String? businessId}) async {
    final result = await _apiClient
        .get<List<PromotionModel>>(
          path,
          queryParameters: {
            'limit': 40,
            'order': 'created_at.desc',
            if (businessId != null) 'negocio_id': businessId,
          },
          parser: (json) {
            return _asList(
              json,
            ).map((item) => PromotionModel.fromJson(item)).toList();
          },
        )
        .timeout(
          _loadTimeout,
          onTimeout: () => const ApiResult.failure(
            ApiFailure(
              code: 'PROMOTIONS_TIMEOUT',
              message: 'La carga de promociones esta tardando demasiado.',
            ),
          ),
        );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PromotionsStatus.success,
          items: const [],
          message:
              result.error?.message ?? 'No se pudieron cargar promociones.',
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

  List<Map<String, dynamic>> _asList(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (json is Map) {
      final raw = json['items'] ?? json['datos'] ?? json['promociones'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (json['id'] != null) return [Map<String, dynamic>.from(json)];
    }
    return const [];
  }
}
