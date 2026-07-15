import 'package:equatable/equatable.dart';

import '../../data/models/cart_delivery_selection_model.dart';
import '../../data/models/cart_item_model.dart';

enum CartStatus { initial, submitting, success, failure }

class CartState extends Equatable {
  const CartState({
    this.items = const [],
    this.deliveryByBusiness = const {},
    this.deliverySelectionByBusiness = const {},
    this.status = CartStatus.initial,
    this.message,
  });

  final List<CartItemModel> items;
  final Map<String, bool> deliveryByBusiness;
  final Map<String, CartDeliverySelection> deliverySelectionByBusiness;
  final CartStatus status;
  final String? message;

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  CartState copyWith({
    List<CartItemModel>? items,
    Map<String, bool>? deliveryByBusiness,
    Map<String, CartDeliverySelection>? deliverySelectionByBusiness,
    CartStatus? status,
    String? message,
  }) {
    return CartState(
      items: items ?? this.items,
      deliveryByBusiness: deliveryByBusiness ?? this.deliveryByBusiness,
      deliverySelectionByBusiness:
          deliverySelectionByBusiness ?? this.deliverySelectionByBusiness,
      status: status ?? this.status,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
        items,
        deliveryByBusiness,
        deliverySelectionByBusiness,
        status,
        message,
      ];
}
