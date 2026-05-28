import 'package:equatable/equatable.dart';

import '../../data/models/review_model.dart';

enum MyReviewsStatus { initial, loading, success, failure }

class MyReviewsState extends Equatable {
  const MyReviewsState({
    this.status = MyReviewsStatus.initial,
    this.items = const [],
    this.message,
  });

  final MyReviewsStatus status;
  final List<ReviewModel> items;
  final String? message;

  MyReviewsState copyWith({
    MyReviewsStatus? status,
    List<ReviewModel>? items,
    String? message,
  }) {
    return MyReviewsState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, items, message];
}
