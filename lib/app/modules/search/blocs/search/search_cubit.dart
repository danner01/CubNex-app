import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/search_results_model.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const SearchState());

  final ApiClient _apiClient;

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, query: query));
    final result = await _apiClient.get<SearchResultsModel>(
      '/busqueda/global',
      queryParameters: {'q': query, 'limit': 12},
      parser: (json) => SearchResultsModel.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );

    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: SearchStatus.success,
          query: query,
          results: result.data,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SearchStatus.failure,
        query: query,
        errorMessage: result.error?.message ?? 'No se pudo buscar.',
      ),
    );
  }
}
