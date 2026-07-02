import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/order_model.dart';
import 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const OrdersState());

  final ApiClient _apiClient;
  static const _loadTimeout = Duration(seconds: 12);
  String? _businessId;
  bool _usingGroupedOrders = true;

  Future<void> load({String? businessId}) async {
    _businessId = businessId;
    emit(state.copyWith(status: OrdersStatus.loading));
    final result = await _loadFrom('/ordenes', businessId: businessId);

    if (result.isSuccess) {
      _usingGroupedOrders = true;
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          items: result.data ?? const [],
        ),
      );
      return;
    }

    final legacyResult = await _loadFrom('/pedidos', businessId: businessId);
    if (legacyResult.isSuccess) {
      _usingGroupedOrders = false;
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          items: legacyResult.data ?? const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OrdersStatus.failure,
        errorMessage:
            result.error?.message ??
            legacyResult.error?.message ??
            'No se pudieron cargar pedidos.',
      ),
    );
  }

  Future<ApiResult<List<OrderModel>>> _loadFrom(
    String path, {
    String? businessId,
  }) {
    return _apiClient
        .get<List<OrderModel>>(
          path,
          queryParameters: {
            'order': 'created_at.desc',
            if (businessId != null) 'negocio_id': businessId,
          },
          parser: (json) {
            if (json is List) {
              return json
                  .whereType<Map>()
                  .map(
                    (item) =>
                        OrderModel.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .toList();
            }
            return const [];
          },
        )
        .timeout(
          _loadTimeout,
          onTimeout: () => const ApiResult.failure(
            ApiFailure(
              code: 'ORDERS_TIMEOUT',
              message: 'La carga de pedidos esta tardando demasiado.',
            ),
          ),
        );
  }

  Future<void> loadBusinessOrders() async {
    emit(state.copyWith(status: OrdersStatus.loading));
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
          status: OrdersStatus.failure,
          errorMessage:
              businessResult.error?.message ?? 'No tienes negocio creado.',
        ),
      );
      return;
    }

    await load(businessId: businessId);
  }

  Future<void> updateStatus(String orderId, String status) async {
    emit(state.copyWith(status: OrdersStatus.saving));
    final path = _usingGroupedOrders
        ? '/ordenes/$orderId/estado'
        : '/pedidos/$orderId';
    final result = await _apiClient.put<void>(
      path,
      data: {'estado': status},
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: OrdersStatus.failure,
          errorMessage:
              result.error?.message ?? 'No se pudo actualizar pedido.',
        ),
      );
      return;
    }

    if (_businessId != null) {
      await load(businessId: _businessId);
    } else {
      await loadBusinessOrders();
    }
  }
}
