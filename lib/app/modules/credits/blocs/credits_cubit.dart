import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../config/http/api_client.dart';
import '../data/models/credit_movement.dart';
import '../data/models/credit_summary.dart';
import '../data/models/verified_topup.dart';
import 'credits_state.dart';

class CreditsCubit extends Cubit<CreditsState> {
  CreditsCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const CreditsState());

  final ApiClient _apiClient;
  int _loadVersion = 0;

  String _operationKey(String operation) =>
      '$operation-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  Future<void> load({bool force = false, String? negocioId}) async {
    final isBusiness = negocioId != null && negocioId.isNotEmpty;
    final walletScope = isBusiness ? 'business:$negocioId' : 'personal';
    final loadVersion = ++_loadVersion;

    emit(
      state.copyWith(
        status: CreditStatus.loading,
        message: null,
        walletScope: walletScope,
        clearWalletData: state.walletScope != walletScope,
      ),
    );

    final summaryResult = await _apiClient.get<CreditSummary>(
      isBusiness
          ? '/negocios/$negocioId/billetera/resumen'
          : '/creditos/mis-creditos',
      parser: (json) {
        if (json is Map) {
          return CreditSummary.fromJson(Map<String, dynamic>.from(json));
        }
        return const CreditSummary(
          balance: 0,
          availableBalance: 0,
          totalEarned: 0,
          totalSpent: 0,
        );
      },
    );

    final historyResult = await _apiClient.get<List<CreditMovement>>(
      isBusiness
          ? '/negocios/$negocioId/billetera/movimientos'
          : '/creditos/movimientos',
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    CreditMovement.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    final topupsResult = await _apiClient.get<List<VerifiedTopupRequest>>(
      isBusiness
          ? '/creditos/recargas-verificadas?negocio_id=$negocioId'
          : '/creditos/recargas-verificadas',
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) => VerifiedTopupRequest.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
        return const [];
      },
    );

    if (isClosed || loadVersion != _loadVersion) return;

    if (!summaryResult.isSuccess) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message:
              summaryResult.error?.message ?? 'No se pudo cargar la billetera.',
          clearWalletData: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CreditStatus.success,
        summary: summaryResult.data,
        movements: historyResult.isSuccess
            ? (historyResult.data ??
                  summaryResult.data?.recentMovements ??
                  const [])
            : (summaryResult.data?.recentMovements ?? const []),
        topupRequests: topupsResult.isSuccess
            ? (topupsResult.data ?? const [])
            : const [],
        message: null,
        walletScope: walletScope,
      ),
    );
  }

  void clear() {
    _loadVersion++;
    emit(const CreditsState());
  }

  Future<void> transferWallet({
    required int amount,
    String? destination,
    String? destinationUserId,
    String? qrPayload,
    String? concept,
    String? sourceNegocioId,
  }) async {
    if (state.status == CreditStatus.submitting) return;

    final trimmedDestination = destination?.trim() ?? '';
    final trimmedUserId = destinationUserId?.trim() ?? '';
    final trimmedQr = qrPayload?.trim() ?? '';
    final trimmedSourceNegocioId = sourceNegocioId?.trim() ?? '';
    final isBusinessSource = trimmedSourceNegocioId.isNotEmpty;

    if (amount <= 0) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: 'Ingresa un monto mayor que cero.',
        ),
      );
      return;
    }

    if (trimmedDestination.isEmpty &&
        trimmedUserId.isEmpty &&
        trimmedQr.isEmpty) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: 'Indica alias, email, teléfono o escanea un QR.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final payload = <String, dynamic>{
      'monto': amount,
      if (isBusinessSource) 'source_negocio_id': trimmedSourceNegocioId,
      if (trimmedUserId.isNotEmpty) 'destination_user_id': trimmedUserId,
      if (trimmedDestination.isNotEmpty) 'alias': trimmedDestination,
      if (trimmedQr.isNotEmpty) 'qr_payload': trimmedQr,
      if (concept != null && concept.trim().isNotEmpty)
        'concepto': concept.trim(),
      'idempotency_key': _operationKey('transfer'),
    };

    final result = await _apiClient.post<void>(
      '/creditos/transferir',
      data: payload,
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message:
              result.error?.message ??
              'No se pudo transferir desde la billetera.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CreditStatus.success,
        message: isBusinessSource
            ? 'Transferencia enviada desde la billetera del negocio.'
            : 'Transferencia enviada desde tu billetera.',
      ),
    );
    await load(
      force: true,
      negocioId: isBusinessSource ? trimmedSourceNegocioId : null,
    );
  }

  Future<void> transferCredits({
    required String recipientEmail,
    required int amount,
  }) {
    return transferWallet(destination: recipientEmail, amount: amount);
  }

  Future<WalletReceivingAccount?> loadReceivingAccount() async {
    final result = await _apiClient.get<WalletReceivingAccount>(
      '/creditos/cuenta-receptora',
      parser: (json) {
        if (json is Map) {
          return WalletReceivingAccount.fromJson(Map<String, dynamic>.from(json));
        }
        throw const FormatException('La cuenta receptora no está disponible.');
      },
    );
    return result.isSuccess ? result.data : null;
  }

  Future<VerifiedTopupRequest?> requestRecharge({
    required int amount,
    required String reference,
    String? sourceNegocioId,
  }) async {
    if (state.status == CreditStatus.submitting) return null;
    if (amount <= 0) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: 'El monto de la recarga debe ser mayor que cero.',
        ),
      );
      return null;
    }
    if (reference.trim().isEmpty) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: 'Indica el código de operación de la transferencia.',
        ),
      );
      return null;
    }

    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final result = await _apiClient.post<VerifiedTopupRequest>(
      '/creditos/recargar',
      data: {
        'monto': amount,
        'referencia': reference,
        if (sourceNegocioId != null && sourceNegocioId.isNotEmpty)
          'negocio_id': sourceNegocioId,
        'idempotency_key': _operationKey('recharge'),
      },
      parser: (json) {
        if (json is Map) {
          final data = Map<String, dynamic>.from(json);
          final request = data['solicitud'];
          if (request is Map) {
            return VerifiedTopupRequest.fromJson(
              Map<String, dynamic>.from(request),
            );
          }
          return VerifiedTopupRequest.fromJson(data);
        }
        throw const FormatException('Respuesta de recarga inválida.');
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: result.error?.message ?? 'No se pudo solicitar la recarga.',
        ),
      );
      return null;
    }

    final request = result.data;
    emit(
      state.copyWith(
        status: CreditStatus.success,
        message: 'Solicitud de recarga por transferencia enviada.',
      ),
    );
    await load(force: true, negocioId: sourceNegocioId);
    return request;
  }

  Future<void> sellCredits({required int amount}) async {
    if (state.status == CreditStatus.submitting) return;
    if (amount <= 0) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: 'La cantidad de granos debe ser mayor que cero.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final result = await _apiClient.post<void>(
      '/creditos/retirar',
      data: {'monto': amount, 'idempotency_key': _operationKey('withdrawal')},
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message:
              result.error?.message ??
              'No se pudo solicitar el retiro de granos.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CreditStatus.success,
        message: 'Solicitud de retiro enviada al superadmin.',
      ),
    );
    await load(force: true);
  }

  Future<void> convertGrains({required int grains, String? negocioId}) async {
    if (state.status == CreditStatus.submitting) return;
    if (grains <= 0) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: 'La cantidad de granos debe ser mayor que cero.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final result = await _apiClient.post<Map<String, dynamic>>(
      '/creditos/convertir-granos',
      data: {
        'granos': grains,
        if (negocioId != null && negocioId.isNotEmpty) 'negocio_id': negocioId,
        'idempotency_key': _operationKey('convert'),
      },
      parser: (json) {
        if (json is Map) {
          return Map<String, dynamic>.from(json);
        }
        return <String, dynamic>{};
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: CreditStatus.failure,
          message: result.error?.message ?? 'No se pudo convertir los granos.',
        ),
      );
      return;
    }

    final data = result.data ?? {};
    final comision = (data['comision'] ?? 0).toDouble();
    final montoNeto = (data['monto_neto'] ?? 0).toDouble();

    final msg = comision > 0
        ? 'Convertidos $grains granos a $montoNeto CUP (comisión: $comision CUP).'
        : 'Convertidos $grains granos a $montoNeto CUP.';

    emit(state.copyWith(status: CreditStatus.success, message: msg));
    await load(force: true, negocioId: negocioId);
  }
}
