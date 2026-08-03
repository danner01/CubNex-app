import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../config/http/api_client.dart';
import '../data/models/credit_movement.dart';
import '../data/models/credit_summary.dart';
import 'credits_state.dart';

class CreditsCubit extends Cubit<CreditsState> {
  CreditsCubit({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const CreditsState());

  final ApiClient _apiClient;
  DateTime? _lastLoadedAt;

  Future<void> load({bool force = false}) async {
    final last = _lastLoadedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20) &&
        state.summary != null &&
        state.status == CreditStatus.success) {
      return;
    }

    emit(state.copyWith(status: CreditStatus.loading, message: null));

    final summaryResult = await _apiClient.get<CreditSummary>(
      '/creditos/mis-creditos',
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
      '/creditos/movimientos',
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) => CreditMovement.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!summaryResult.isSuccess) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message:
            summaryResult.error?.message ?? 'No se pudo cargar la billetera.',
      ));
      return;
    }

    _lastLoadedAt = DateTime.now();
    emit(state.copyWith(
      status: CreditStatus.success,
      summary: summaryResult.data,
      movements: historyResult.isSuccess
          ? (historyResult.data ??
              summaryResult.data?.recentMovements ??
              const [])
          : (summaryResult.data?.recentMovements ?? const []),
      message: null,
    ));
  }

  Future<void> transferWallet({
    required int amount,
    String? destination,
    String? destinationUserId,
    String? qrPayload,
    String? concept,
  }) async {
    final trimmedDestination = destination?.trim() ?? '';
    final trimmedUserId = destinationUserId?.trim() ?? '';
    final trimmedQr = qrPayload?.trim() ?? '';

    if (amount <= 0) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message: 'Ingresa un monto mayor que cero.',
      ));
      return;
    }

    if (trimmedDestination.isEmpty &&
        trimmedUserId.isEmpty &&
        trimmedQr.isEmpty) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message: 'Indica alias, email, teléfono o escanea un QR.',
      ));
      return;
    }

    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final payload = <String, dynamic>{
      'monto': amount,
      if (trimmedUserId.isNotEmpty) 'destination_user_id': trimmedUserId,
      if (trimmedDestination.isNotEmpty) 'alias': trimmedDestination,
      if (trimmedQr.isNotEmpty) 'qr_payload': trimmedQr,
      if (concept != null && concept.trim().isNotEmpty)
        'concepto': concept.trim(),
    };

    final result = await _apiClient.post<void>(
      '/creditos/transferir',
      data: payload,
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message: result.error?.message ??
            'No se pudo transferir desde la billetera.',
      ));
      return;
    }

    emit(state.copyWith(
      status: CreditStatus.success,
      message: 'Transferencia enviada desde tu billetera.',
    ));
    await load(force: true);
  }

  Future<void> transferCredits({
    required String recipientEmail,
    required int amount,
  }) {
    return transferWallet(destination: recipientEmail, amount: amount);
  }

  Future<void> requestRecharge({
    required int amount,
    required String method,
    required String reference,
  }) async {
    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final result = await _apiClient.post<void>(
      '/creditos/recargar',
      data: {
        'monto': amount,
        'metodo': method,
        'referencia': reference,
      },
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message: result.error?.message ?? 'No se pudo solicitar la recarga.',
      ));
      return;
    }

    emit(state.copyWith(
      status: CreditStatus.success,
      message: 'Solicitud de recarga enviada.',
    ));
    await load(force: true);
  }

  Future<void> sellCredits({
    required int amount,
  }) async {
    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final result = await _apiClient.post<void>(
      '/creditos/retirar',
      data: {'monto': amount},
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message: result.error?.message ??
            'No se pudo solicitar el retiro de granos.',
      ));
      return;
    }

    emit(state.copyWith(
      status: CreditStatus.success,
      message: 'Solicitud de retiro enviada al superadmin.',
    ));
    await load(force: true);
  }
}
