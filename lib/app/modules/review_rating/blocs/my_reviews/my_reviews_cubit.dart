import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/review_model.dart';
import 'my_reviews_state.dart';

class MyReviewsCubit extends Cubit<MyReviewsState> {
  MyReviewsCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const MyReviewsState());

  final ApiClient _apiClient;

  Future<void> load() async {
    emit(state.copyWith(status: MyReviewsStatus.loading));
    final result = await _apiClient.get<List<ReviewModel>>(
      '/resenas/mis-resenas',
      queryParameters: {'limit': 60, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: MyReviewsStatus.failure,
          message: result.error?.message ?? 'No se pudieron cargar resenas.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: MyReviewsStatus.success,
        items: result.data ?? const [],
      ),
    );
  }
}
