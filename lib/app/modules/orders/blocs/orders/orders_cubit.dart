import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../../../common/services/offline_sync_service.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/order_model.dart';
import 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const OrdersState()) {
    OfflineSyncService.instance.syncTick.addListener(_onSynced);
  }

  final ApiClient _apiClient;
  static const _groupedLoadTimeout = Duration(seconds: 4);
  static const _legacyLoadTimeout = Duration(seconds: 4);
  String? _businessId;
  Set<String> _groupedOrderIds = const <String>{};
  Set<String> _requestOrderIds = const <String>{};
  int _loadSequence = 0;
  final Map<String, Map<String, dynamic>> _fetchedRaw = {};

  void _onSynced() {
    if (isClosed) return;
    unawaited(load(businessId: _businessId));
  }

  @override
  Future<void> close() {
    OfflineSyncService.instance.syncTick.removeListener(_onSynced);
    return super.close();
  }

  Future<void> load({String? businessId}) async {
    _businessId = businessId;
    final loadSequence = ++_loadSequence;
    if (state.items.isEmpty) {
      emit(state.copyWith(status: OrdersStatus.loading));
    }
    final futures = <Future<ApiResult<List<OrderModel>>>>[
      _loadFrom(
        '/ordenes',
        businessId: businessId,
        timeout: _groupedLoadTimeout,
      ),
      _loadFrom(
        '/pedidos',
        businessId: businessId,
        timeout: _legacyLoadTimeout,
      ),
    ];

    final results = await Future.wait<ApiResult<List<OrderModel>>>(
      futures,
      eagerError: false,
    );
    if (isClosed || loadSequence != _loadSequence) return;

    final groupedResult = results[0];
    final legacyResult = results[1];
    final groupedOrders = groupedResult.data ?? const <OrderModel>[];
    final legacyOrders = legacyResult.data ?? const <OrderModel>[];
    final hasAnyOrders = groupedOrders.isNotEmpty || legacyOrders.isNotEmpty;
    final allSourcesSucceeded = groupedResult.isSuccess && legacyResult.isSuccess;

    if (hasAnyOrders || allSourcesSucceeded) {
      _groupedOrderIds = groupedOrders.map((order) => order.id).toSet();
      _requestOrderIds = const <String>{};
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
      final merged = await _withLocalChanges(items);
      if (isClosed || loadSequence != _loadSequence) return;
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          items: merged,
          errorMessage: groupedResult.isSuccess || legacyResult.isSuccess
              ? null
              : 'No se pudieron actualizar todos los pedidos.',
        ),
      );
      return;
    }

    if (await _emitFromCache(businessId: businessId)) return;

    emit(
      state.copyWith(
        status: state.items.isEmpty ? OrdersStatus.failure : OrdersStatus.success,
        items: state.items.isEmpty ? const [] : state.items,
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
    Duration timeout = _legacyLoadTimeout,
    Map<String, dynamic>? extraQuery,
  }) {
    return _apiClient
        .get<List<OrderModel>>(
          path,
          queryParameters: {
            'limit': 20,
            'order': 'created_at.desc',
            if (businessId != null) 'negocio_id': businessId,
            ...?extraQuery,
          },
          parser: (json) {
            final raw = _asList(json);
            for (final item in raw) {
              final id = item['id']?.toString();
              if (id != null) _fetchedRaw[id] = item;
            }
            unawaited(
              OfflineSyncService.instance.saveOrders(
                raw,
                source: path == '/ordenes' ? 'ordenes' : 'pedidos',
                ownedByBusiness: businessId != null,
              ),
            );
            return raw.map((item) => OrderModel.fromJson(item)).toList();
          },
        )
        .timeout(
          timeout,
          onTimeout: () => const ApiResult.failure(
            ApiFailure(
              code: 'ORDERS_TIMEOUT',
              message: 'La carga de pedidos esta tardando demasiado.',
            ),
          ),
        );
  }

  /// Aplica cambios hechos sin conexion y agrega reservas aun no enviadas.
  Future<List<OrderModel>> _withLocalChanges(List<OrderModel> items) async {
    final sync = OfflineSyncService.instance;
    final overrides = await sync.overrides();
    final result = items.map((order) {
      final override = overrides[order.id];
      final raw = _fetchedRaw[order.id];
      if (override == null || raw == null) return order;
      return OrderModel.fromJson({...raw, 'estado': override});
    }).toList();
    final local = await sync.localPendingOrders();
    if (local.isEmpty) return result;
    final known = result.map((o) => o.id).toSet();
    return [
      ...local
          .where((o) => !known.contains(o['id']))
          .map(OrderModel.fromJson),
      ...result,
    ];
  }

  /// Sin conexion: muestra los pedidos guardados en el dispositivo con los
  /// cambios locales aplicados.
  Future<bool> _emitFromCache({String? businessId, String? notice}) async {
    final sync = OfflineSyncService.instance;
    var raw = await sync.cachedOrders(businessId: businessId);
    raw = await sync.applyOverrides(raw);
    if (raw.isEmpty) return false;
    _groupedOrderIds = raw
        .where((o) => o['_src'] == 'ordenes')
        .map((o) => o['id'].toString())
        .toSet();
    final items = raw.map(OrderModel.fromJson).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    if (isClosed) return true;
    emit(
      state.copyWith(
        status: OrdersStatus.success,
        items: items,
        errorMessage:
            notice ?? 'Sin conexion: mostrando pedidos guardados en este dispositivo.',
      ),
    );
    return true;
  }

  Future<void> loadBusinessOrders() async {
    if (state.items.isEmpty) {
      emit(state.copyWith(status: OrdersStatus.loading));
    }
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
          _legacyLoadTimeout,
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
    return updateStatusWithOptions(orderId, status: status);
  }

  Future<void> updateStatusWithOptions(
    String orderId, {
    required String status,
    int? reservationMinutes,
  }) async {
    emit(state.copyWith(status: OrdersStatus.saving));
    final path = _groupedOrderIds.contains(orderId)
        ? '/ordenes/$orderId/estado'
        : _requestOrderIds.contains(orderId)
            ? '/solicitudes-red/$orderId'
            : '/pedidos/$orderId';
    final payload = <String, dynamic>{'estado': status};
    if (reservationMinutes != null && reservationMinutes > 0) {
      payload['caduca_en_minutos'] = reservationMinutes;
    }
    final result = await _apiClient.put<void>(
      path,
      data: payload,
      parser: (_) {},
    );

    if (!result.isSuccess) {
      if (isNetworkFailure(result.error)) {
        final sync = OfflineSyncService.instance;
        await sync.setOverride(orderId, status);
        await sync.enqueue(
          PendingOp(
            id: sync.newId(),
            kind: 'order_status',
            method: 'PUT',
            path: path,
            body: payload,
            createdAt: DateTime.now(),
            orderId: orderId,
          ),
        );
        if (await _emitFromCache(
          businessId: _businessId,
          notice:
              'Sin conexion: cambio guardado y se sincronizara al volver internet.',
        )) {
          return;
        }
      }
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
