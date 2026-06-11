import 'package:equatable/equatable.dart';

import '../../data/models/search_results_model.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.results = const SearchResultsModel(),
    this.errorMessage,
    this.loadingMore = false,
    this.hasMore = false,
    this.offset = 0,
  });

  final SearchStatus status;
  final String query;
  final SearchResultsModel results;
  final String? errorMessage;
  final bool loadingMore;
  final bool hasMore;
  final int offset;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchResultsModel? results,
    String? errorMessage,
    bool? loadingMore,
    bool? hasMore,
    int? offset,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      errorMessage: errorMessage,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
    );
  }

  @override
  List<Object?> get props => [
    status,
    query,
    results,
    errorMessage,
    loadingMore,
    hasMore,
    offset,
  ];
}
