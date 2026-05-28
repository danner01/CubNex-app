import '../../../home/data/models/product_model.dart';

class CartItemModel {
  const CartItemModel({
    required this.product,
    this.quantity = 1,
  });

  final ProductModel product;
  final int quantity;

  double get subtotal => (product.currentPrice ?? 0) * quantity;

  CartItemModel copyWith({ProductModel? product, int? quantity}) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
