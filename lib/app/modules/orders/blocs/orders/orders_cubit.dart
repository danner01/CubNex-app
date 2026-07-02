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
  Set<String> _groupedOrderIds = const <String>{};

  Future<void> load({String? businessId}) async {
    _businessId = businessId;
    emit(state.copyWith(status: OrdersStatus.loading));
    final results = await Future.wait<ApiResult<List<OrderModel>>>([
      _loadFrom('/ordenes', businessId: businessId),
      _loadFrom('/pedidos', businessId: businessId),
    ]);

    final groupedResult = results[0];
    final legacyResult = results[1];
    if (groupedResult.isSuccess || legacyResult.isSuccess) {
      final groupedOrders = groupedResult.data ?? const <OrderModel>[];
      final legacyOrders = legacyResult.data ?? const <OrderModel>[];
      _groupedOrderIds = groupedOrders.map((order) => order.id).toSet();
      final byId = <String, OrderModel>{};
      for (final order in [...groupedOrders, ...legacyOrders]) {
        if (order.id.isNotEmpty) {
          byId[order.id] = order;
        }
      }
      final items = byId.values.toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          items: items,
          errorMessage: groupedResult.isSuccess
              ? null
              : groupedResult.error?.message,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: OrdersStatus.success,
        items: const [],
        errorMessage:
            groupedResult.error?.message ??
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
            'limit': 50,
            'order': 'created_at.desc',
            if (businessId != null) 'negocio_id': businessId,
          },
          parser: (json) {
            return _asList(
              json,
            ).map((item) => OrderModel.fromJson(item)).toList();
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

  List<Map<String, dynamic>> _asList(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (json is Map) {
      final raw = json['items'] ?? json['datos'] ?? json['ordenes'];
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

  Future<void> updateStatus(String orderId, String status) async {
    emit(state.copyWith(status: OrdersStatus.saving));
    final path = _groupedOrderIds.contains(orderId)
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
      await load();
    }
  }
}
