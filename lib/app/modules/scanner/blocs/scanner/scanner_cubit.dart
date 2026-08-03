import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import 'scanner_state.dart';

class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const ScannerState());

  final ApiClient _apiClient;
  bool _processing = false;

  Future<void> processCode(String rawValue) async {
    final code = rawValue.trim();
    if (code.isEmpty || _processing) return;

    _processing = true;
    emit(
      state.copyWith(
        status: ScannerStatus.resolving,
        code: code,
        orderQrValidated: false,
      ),
    );
    await _saveScan(code);

        final walletParts = _extractWalletQr(code);
        if (walletParts != null) {
      emit(
        state.copyWith(
              status: ScannerStatus.success,
              orderQrValidated: false,
              walletQrDetected: true,
              walletUserId: walletParts.userId,
              walletAlias: walletParts.alias,
              walletQrPayload: code,
              message: 'QR de billetera detectado.',
            ),
          );
          _processing = false;
          return;
        }

        final orderQrToken = _extractOrderQrToken(code);
        if (orderQrToken == null) {
          emit(
            state.copyWith(
              status: ScannerStatus.failure,
              message:
                  'QR no valido. Escanea un QR de pedido o de billetera ConKkao.',
              orderQrValidated: false,
              walletQrDetected: false,
            ),
          );
          _processing = false;
          return;
        }

        await _validateOrderQr(orderQrToken);
        _processing = false;
      }

      ({String? userId, String? alias})? _extractWalletQr(String code) {
        final trimmed = code.trim();
        final lower = trimmed.toLowerCase();
        final looksWallet = lower.startsWith('conkkao://wallet') ||
            lower.contains('wallet/pay') ||
            (lower.contains('uid=') && lower.contains('alias='));
        if (!looksWallet) return null;

        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          final userId = uri.queryParameters['uid'] ??
              uri.queryParameters['user_id'] ??
              uri.queryParameters['usuario_id'];
          final alias = uri.queryParameters['alias'] ??
              uri.queryParameters['email'] ??
              uri.queryParameters['telefono'];
          if ((userId != null && userId.isNotEmpty) ||
              (alias != null && alias.isNotEmpty)) {
            return (userId: userId, alias: alias);
          }
        }

        final uidMatch = RegExp(
          r'(?:uid|user_id|usuario_id)=([0-9a-fA-F-]{36})',
          caseSensitive: false,
        ).firstMatch(trimmed);
        final aliasMatch = RegExp(
          r'(?:alias|email|telefono)=([^&\s]+)',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (uidMatch == null && aliasMatch == null) return null;
        return (
          userId: uidMatch?.group(1),
          alias: aliasMatch != null
              ? Uri.decodeComponent(aliasMatch.group(1)!)
              : null,
        );
      }

  Future<void> _validateOrderQr(String token) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/ordenes/validar-qr',
      data: {'token': token},
      parser: (json) {
        if (json is Map) {
          return Map<String, dynamic>.from(json);
        }
        return <String, dynamic>{};
      },
    );

    if (!result.isSuccess) {
      final serverMessage =
          result.error?.message ?? 'No se pudo validar el QR de la orden.';
      final normalized = serverMessage.toLowerCase();
      final message =
          normalized.contains('no puede cambiar el estado para tu rol')
          ? '$serverMessage Verifica que el QR se escanee por el rol correcto en esta etapa.'
          : serverMessage;
      emit(
        state.copyWith(
          status: ScannerStatus.failure,
          message: message,
          orderQrValidated: false,
        ),
      );
      return;
    }

    final payload = result.data ?? const <String, dynamic>{};
    final nextStatus = payload['estado_nuevo']?.toString();
    final previousStatus = payload['estado_anterior']?.toString();
    final order = payload['orden'];
    final orderId = order is Map ? order['id']?.toString() : null;

    final statusMessage =
        nextStatus == null || nextStatus.isEmpty
        ? 'QR validado correctamente.'
        : previousStatus == null || previousStatus.isEmpty
        ? 'Pedido actualizado a: $nextStatus.'
        : 'Pedido actualizado: $previousStatus -> $nextStatus.';

    emit(
      state.copyWith(
        status: ScannerStatus.success,
        orderQrValidated: true,
        message:
            orderId == null || orderId.isEmpty
            ? statusMessage
            : '$statusMessage Orden: ${orderId.substring(0, math.min(8, orderId.length))}',
      ),
    );
  }

  String? _extractOrderQrToken(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;

    final directToken = RegExp(r'(qrt_[A-Za-z0-9_-]+)', caseSensitive: false)
        .firstMatch(trimmed)
        ?.group(1);
    if (directToken != null && directToken.isNotEmpty) {
      return directToken;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    for (var index = 0; index < uri.pathSegments.length - 2; index++) {
      if (uri.pathSegments[index].toLowerCase() == 'ordenes' &&
          uri.pathSegments[index + 1].toLowerCase() == 'qr') {
        final token = uri.pathSegments[index + 2].trim();
        if (token.isNotEmpty) return token;
      }
    }

    final queryToken =
        uri.queryParameters['token'] ??
        uri.queryParameters['qr'] ??
        uri.queryParameters['qr_codigo'];
    if (queryToken != null && queryToken.trim().isNotEmpty) {
      return queryToken.trim();
    }

    return null;
  }

  void restart() {
    _processing = false;
    emit(const ScannerState());
  }

  Future<void> _saveScan(String code) async {
    await _apiClient.post<void>(
      '/historial/escaneos',
      data: {'tipo': _scanType(code), 'contenido': code},
      parser: (_) {},
    );
  }

  String _scanType(String code) {
    final lower = code.toLowerCase();
      if (lower.startsWith('conkkao://wallet') || lower.contains('wallet/pay')) {
        return 'qr_billetera';
      }
      if (lower.contains('qr') || lower.startsWith('http')) return 'qr_producto';
      return 'codigo_barras';
    }
}
