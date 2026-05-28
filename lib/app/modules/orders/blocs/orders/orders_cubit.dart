import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/order_model.dart';
import 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const OrdersState());

  final ApiClient _apiClient;
  String? _businessId;

  Future<void> load({String? businessId}) async {
    _businessId = businessId;
    emit(state.copyWith(status: OrdersStatus.loading));
    final result = await _apiClient.get<List<OrderModel>>(
      '/pedidos',
      queryParameters: {
        'order': 'created_at.desc',
        if (businessId != null) 'negocio_id': businessId,
      },
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return const [];
      },
    );

    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          items: result.data ?? const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OrdersStatus.failure,
        errorMessage: result.error?.message ?? 'No se pudieron cargar pedidos.',
      ),
    );
  }

  Future<void> loadBusinessOrders() async {
    emit(state.copyWith(status: OrdersStatus.loading));
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
          status: OrdersStatus.failure,
          errorMessage: businessResult.error?.message ?? 'No tienes negocio creado.',
        ),
      );
      return;
    }

    await load(businessId: businessId);
  }

  Future<void> updateStatus(String orderId, String status) async {
    emit(state.copyWith(status: OrdersStatus.saving));
    final result = await _apiClient.put<void>(
      '/pedidos/$orderId',
      data: {'estado': status},
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: OrdersStatus.failure,
          errorMessage: result.error?.message ?? 'No se pudo actualizar pedido.',
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
