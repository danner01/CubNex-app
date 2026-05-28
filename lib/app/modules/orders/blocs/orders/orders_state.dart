import 'package:equatable/equatable.dart';

import '../../data/models/order_model.dart';

enum OrdersStatus { initial, loading, success, failure, saving }

class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final OrdersStatus status;
  final List<OrderModel> items;
  final String? errorMessage;

  OrdersState copyWith({
    OrdersStatus? status,
    List<OrderModel>? items,
    String? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
