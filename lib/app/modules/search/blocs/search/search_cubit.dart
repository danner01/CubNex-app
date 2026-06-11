import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/search_results_model.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const SearchState());

  final ApiClient _apiClient;
  static const _pageSize = 10;

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, query: query));
    final result = await _apiClient.get<SearchResultsModel>(
      '/busqueda/global',
      queryParameters: {'q': query, 'limit': _pageSize, 'offset': 0},
      parser: (json) =>
          SearchResultsModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );

    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: SearchStatus.success,
          query: query,
          results: result.data,
          offset: _pageSize,
          hasMore: result.data!.hasPageWithAtLeast(_pageSize),
          loadingMore: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SearchStatus.failure,
        query: query,
        errorMessage: result.error?.message ?? 'No se pudo buscar.',
        loadingMore: false,
        hasMore: false,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.query.trim().isEmpty) {
      return;
    }

    emit(state.copyWith(loadingMore: true, errorMessage: null));
    final result = await _apiClient.get<SearchResultsModel>(
      '/busqueda/global',
      queryParameters: {
        'q': state.query,
        'limit': _pageSize,
        'offset': state.offset,
      },
      parser: (json) =>
          SearchResultsModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );

    if (result.isSuccess && result.data != null) {
      final next = result.data!;
      emit(
        state.copyWith(
          status: SearchStatus.success,
          results: state.results.merge(next),
          loadingMore: false,
          hasMore: next.hasPageWithAtLeast(_pageSize),
          offset: state.offset + _pageSize,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        loadingMore: false,
        errorMessage:
            result.error?.message ?? 'No se pudieron cargar mas resultados.',
      ),
    );
  }
}
