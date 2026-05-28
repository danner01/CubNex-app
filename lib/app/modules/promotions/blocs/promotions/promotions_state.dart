import 'package:equatable/equatable.dart';

import '../../data/models/promotion_model.dart';

enum PromotionsStatus { initial, loading, success, failure, saving }

class PromotionsState extends Equatable {
  const PromotionsState({
    this.status = PromotionsStatus.initial,
    this.items = const [],
    this.businessId,
    this.message,
  });

  final PromotionsStatus status;
  final List<PromotionModel> items;
  final String? businessId;
  final String? message;

  PromotionsState copyWith({
    PromotionsStatus? status,
    List<PromotionModel>? items,
    String? businessId,
    String? message,
  }) {
    return PromotionsState(
      status: status ?? this.status,
      items: items ?? this.items,
      businessId: businessId ?? this.businessId,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, items, businessId, message];
}
