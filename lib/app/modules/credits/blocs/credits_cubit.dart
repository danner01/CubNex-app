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

  Future<void> load() async {
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

    if (!summaryResult.isSuccess || !historyResult.isSuccess) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message: summaryResult.error?.message ??
            historyResult.error?.message ??
            'No se pudo cargar los créditos.',
      ));
      return;
    }

    emit(state.copyWith(
      status: CreditStatus.success,
      summary: summaryResult.data,
      movements: historyResult.data ?? summaryResult.data?.recentMovements ?? const [],
      message: null,
    ));
  }

  Future<void> transferCredits({
    required String recipientEmail,
    required int amount,
  }) async {
    emit(state.copyWith(status: CreditStatus.submitting, message: null));

    final result = await _apiClient.post<void>(
      '/creditos/transferir',
      data: {
        'email_destinatario': recipientEmail,
        'monto': amount,
      },
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(state.copyWith(
        status: CreditStatus.failure,
        message: result.error?.message ?? 'No se pudo transferir créditos.',
      ));
      return;
    }

    emit(state.copyWith(
      status: CreditStatus.success,
      message: 'Transferencia de créditos enviada.',
    ));
    await load();
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
    await load();
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
        message: result.error?.message ?? 'No se pudo solicitar el retiro de granos.',
      ));
      return;
    }

    emit(state.copyWith(
      status: CreditStatus.success,
      message: 'Solicitud de retiro enviada al superadmin.',
    ));
    await load();
  }
}
