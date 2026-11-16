import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/http/api_client.dart';
import '../../config/http/api_result.dart';

/// Operacion pendiente de enviar al servidor (se guardo sin conexion).
class PendingOp {
  const PendingOp({
    required this.id,
    required this.kind,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.localId,
  });

  final String id;

  /// order_status | order_qr | order_create
  final String kind;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final String? orderId;
  final String? localId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'method': method,
    'path': path,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'orderId': orderId,
    'localId': localId,
  };

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
    id: json['id'].toString(),
    kind: json['kind'].toString(),
    method: json['method'].toString(),
    path: json['path'].toString(),
    body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
    createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    orderId: json['orderId']?.toString(),
    localId: json['localId']?.toString(),
  );
}

bool isNetworkFailure(ApiFailure? failure) {
  if (failure == null) return false;
  if (failure.code == 'TIMEOUT') return true;
  return failure.code == 'ERROR_RED' && failure.statusCode == null;
}

/// Cola offline + cache local de pedidos. Todo cambio hecho sin conexion se
/// guarda aqui, se refleja de inmediato en el dispositivo y se envia en orden
/// cuando vuelve la red.
class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const _queueBox = 'offline_queue';
  static const _ordersBox = 'orders_cache';
  static const _overridesBox = 'order_overrides';
  static const _conflictsBox = 'sync_conflicts';

  /// Cantidad de operaciones pendientes (para mostrar el aviso en la UI).
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Se incrementa cada vez que una sincronizacion aplico cambios al servidor.
  final ValueNotifier<int> syncTick = ValueNotifier<int>(0);

  /// Mensajes de conflicto (el servidor rechazo un cambio hecho offline).
  final ValueNotifier<List<String>> conflicts = ValueNotifier<List<String>>(
    const [],
  );

  ApiClient? _api;
  Timer? _timer;
  bool _flushing = false;

  Future<Box<dynamic>> _open(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
  }

  Future<void> start(ApiClient api) async {
    _api = api;
    await _refreshCount();
    final box = await _open(_conflictsBox);
    conflicts.value = box.values.map((e) => e.toString()).toList();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(flush());
    });
    unawaited(flush());
  }

  Future<void> _refreshCount() async {
    final box = await _open(_queueBox);
    pendingCount.value = box.length;
  }

  Future<List<PendingOp>> pending() async {
    final box = await _open(_queueBox);
    final ops = <PendingOp>[];
    for (final value in box.values) {
      try {
        ops.add(
          PendingOp.fromJson(
            Map<String, dynamic>.from(jsonDecode(value as String) as Map),
          ),
        );
      } catch (_) {}
    }
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  Future<void> enqueue(PendingOp op) async {
    final box = await _open(_queueBox);
    await box.put(op.id, jsonEncode(op.toJson()));
    await _refreshCount();
    unawaited(flush());
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}';

  Future<void> clearConflicts() async {
    final box = await _open(_conflictsBox);
    await box.clear();
    conflicts.value = const [];
  }

  Future<void> _addConflict(String message) async {
    final box = await _open(_conflictsBox);
    await box.add(message);
    if (box.length > 20) await box.deleteAt(0);
    conflicts.value = box.values.map((e) => e.toString()).toList();
  }

  /// Envia las operaciones pendientes en orden. Se detiene al primer fallo de
  /// red y descarta (con aviso) las que el servidor rechaza por conflicto.
  Future<void> flush() async {
    final api = _api;
    if (api == null || _flushing) return;
    _flushing = true;
    var applied = false;
    try {
      final ops = await pending();
      if (ops.isEmpty) return;
      if (!await api.hasLocalSession()) return;
      final queue = await _open(_queueBox);
      for (final op in ops) {
        final ApiResult<void> result;
        if (op.method == 'PUT') {
          result = await api.put<void>(
            op.path,
            data: op.body,
            parser: (_) {},
            timeout: const Duration(seconds: 12),
          );
        } else {
          result = await api.post<void>(
            op.path,
            data: op.body,
            parser: (_) {},
            timeout: const Duration(seconds: 12),
          );
        }
        if (!result.isSuccess) {
          final failure = result.error;
          if (isNetworkFailure(failure) || failure?.code == 'AUTH_REQUIRED') {
            break;
          }
          if ((failure?.statusCode ?? 500) >= 500) break;
          await _addConflict(
            '${_describe(op)}: ${failure?.message ?? 'rechazado por el servidor'}',
          );
        }
        await queue.delete(op.id);
        if (op.orderId != null) await clearOverride(op.orderId!);
        if (op.localId != null) await removeOrder(op.localId!);
        applied = true;
      }
    } finally {
      _flushing = false;
      await _refreshCount();
      if (applied) syncTick.value++;
    }
  }

  String _describe(PendingOp op) => switch (op.kind) {
    'order_create' => 'Reserva hecha sin conexion',
    'order_qr' => 'Pedido escaneado sin conexion',
    _ => 'Cambio de estado sin conexion',
  };

  // ---- Cache local de pedidos ----

  Future<void> saveOrders(
    List<Map<String, dynamic>> raw, {
    required String source,
    bool ownedByBusiness = false,
  }) async {
    final box = await _open(_ordersBox);
    final entries = <String, String>{};
    for (final order in raw) {
      final id = order['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final stored = <String, dynamic>{
        ...order,
        '_src': source,
        '_biz_owner':
            ownedByBusiness || _decode(box.get(id))?['_biz_owner'] == true,
      };
      entries[id] = jsonEncode(stored);
    }
    await box.putAll(entries);
  }

  Future<List<Map<String, dynamic>>> cachedOrders({String? businessId}) async {
    final box = await _open(_ordersBox);
    final result = <Map<String, dynamic>>[];
    for (final value in box.values) {
      final order = _decode(value);
      if (order == null) continue;
      if (businessId != null && order['negocio_id']?.toString() != businessId) {
        continue;
      }
      result.add(order);
    }
    return result;
  }

  Future<Map<String, dynamic>?> findOrderByQrToken(String token) async {
    final box = await _open(_ordersBox);
    for (final value in box.values) {
      if (value is String && value.contains(token)) return _decode(value);
    }
    return null;
  }

  Future<void> addLocalOrder(String localId, Map<String, dynamic> raw) async {
    final box = await _open(_ordersBox);
    await box.put(
      localId,
      jsonEncode({
        ...raw,
        'id': localId,
        '_local': true,
        'created_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> removeOrder(String id) async {
    final box = await _open(_ordersBox);
    await box.delete(id);
  }

  Map<String, dynamic>? _decode(dynamic value) {
    if (value is! String) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return null;
    }
  }

  // ---- Estados cambiados localmente (pendientes de sincronizar) ----

  Future<void> setOverride(String orderId, String status) async {
    final box = await _open(_overridesBox);
    await box.put(orderId, status);
  }

  Future<void> clearOverride(String orderId) async {
    final box = await _open(_overridesBox);
    await box.delete(orderId);
  }

  Future<Map<String, String>> overrides() async {
    final box = await _open(_overridesBox);
    return {for (final k in box.keys) '$k': '${box.get(k)}'};
  }

  /// Aplica estados locales pendientes y reconstruye pedidos creados offline.
  Future<List<Map<String, dynamic>>> applyOverrides(
    List<Map<String, dynamic>> orders,
  ) async {
    final map = await overrides();
    if (map.isEmpty) return orders;
    return orders
        .map(
          (o) => map.containsKey(o['id']?.toString())
              ? {...o, 'estado': map[o['id'].toString()]}
              : o,
        )
        .toList();
  }

  /// Reservas creadas sin conexion que aun no llegaron al servidor.
  Future<List<Map<String, dynamic>>> localPendingOrders() async {
    final all = await cachedOrders();
    return all.where((o) => o['_local'] == true).toList();
  }
}
