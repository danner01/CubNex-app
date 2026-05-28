import 'package:equatable/equatable.dart';

import '../../../home/data/models/product_model.dart';

enum ProductDetailStatus { initial, loading, success, failure }

class ProductDetailState extends Equatable {
  const ProductDetailState({
    this.status = ProductDetailStatus.initial,
    this.product,
    this.errorMessage,
  });

  final ProductDetailStatus status;
  final ProductModel? product;
  final String? errorMessage;

  ProductDetailState copyWith({
    ProductDetailStatus? status,
    ProductModel? product,
    String? errorMessage,
  }) {
    return ProductDetailState(
      status: status ?? this.status,
      product: product ?? this.product,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, product, errorMessage];
}
