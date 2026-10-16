import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../common/services/semilla_reward_service.dart';
import '../../data/models/gamification_level.dart';
import '../../data/models/gamification_summary.dart';
import 'gamification_state.dart';

class GamificationCubit extends Cubit<GamificationState> {
  GamificationCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const GamificationState());

  final ApiClient _apiClient;

  Future<void> load() async {
    emit(state.copyWith(status: GamificationStatus.loading));

    final summaryResult = await _apiClient.get<GamificationSummary>(
      '/gamificacion/mis-puntos',
      parser: (json) => json is Map
          ? GamificationSummary.fromJson(Map<String, dynamic>.from(json))
          : const GamificationSummary(
              points: 0,
              level: 'bronce',
              totalPurchases: 0,
              totalReviews: 0,
            ),
    );
    final levelsResult = await _apiClient.get<List<GamificationLevel>>(
      '/gamificacion/niveles',
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    GamificationLevel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!summaryResult.isSuccess || !levelsResult.isSuccess) {
      emit(
        state.copyWith(
          status: GamificationStatus.failure,
          message:
              summaryResult.error?.message ??
              levelsResult.error?.message ??
              'No se pudo cargar la gamificacion.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: GamificationStatus.success,
        summary: summaryResult.data,
        levels: levelsResult.data ?? const [],
      ),
    );

    final newPoints = summaryResult.data?.points;
    if (newPoints != null) {
      sl<SemillaRewardService>().showIfIncreased(
        'gamification',
        newPoints,
        unit: 'puntos',
        label: '¡Recompensa ConKkao!',
      );
    }
  }
}
