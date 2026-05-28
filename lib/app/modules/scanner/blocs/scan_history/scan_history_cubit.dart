import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/scan_history_item.dart';
import 'scan_history_state.dart';

class ScanHistoryCubit extends Cubit<ScanHistoryState> {
  ScanHistoryCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const ScanHistoryState());

  final ApiClient _apiClient;

  Future<void> load() async {
    emit(state.copyWith(status: ScanHistoryStatus.loading));
    final result = await _apiClient.get<List<ScanHistoryItem>>(
      '/historial/escaneos',
      queryParameters: {'limit': 60, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    ScanHistoryItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: ScanHistoryStatus.failure,
          message: result.error?.message ?? 'No se pudo cargar el historial.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ScanHistoryStatus.success,
        items: result.data ?? const [],
      ),
    );
  }
}
