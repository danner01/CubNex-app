import 'package:equatable/equatable.dart';

import '../../data/models/favorite_model.dart';

enum FavoritesStatus { initial, loading, success, failure, deleting }

class FavoritesState extends Equatable {
  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.items = const [],
    this.errorMessage,
    this.message,
  });

  final FavoritesStatus status;
  final List<FavoriteModel> items;
  final String? errorMessage;
  final String? message;

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<FavoriteModel>? items,
    String? errorMessage,
    String? message,
  }) {
    return FavoritesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage, message];
}
