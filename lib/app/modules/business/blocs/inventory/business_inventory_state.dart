import 'package:equatable/equatable.dart';

import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';

enum BusinessInventoryStatus { initial, loading, success, failure, saving }

class BusinessInventoryState extends Equatable {
  const BusinessInventoryState({
    this.status = BusinessInventoryStatus.initial,
    this.business,
    this.products = const [],
    this.message,
  });

  final BusinessInventoryStatus status;
  final BusinessModel? business;
  final List<ProductModel> products;
  final String? message;

  BusinessInventoryState copyWith({
    BusinessInventoryStatus? status,
    BusinessModel? business,
    List<ProductModel>? products,
    String? message,
  }) {
    return BusinessInventoryState(
      status: status ?? this.status,
      business: business ?? this.business,
      products: products ?? this.products,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, business, products, message];
}
