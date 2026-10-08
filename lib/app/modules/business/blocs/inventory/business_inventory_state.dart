import 'package:equatable/equatable.dart';

import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';
import '../../data/models/business_product_cost.dart';

enum BusinessInventoryStatus { initial, loading, success, failure, saving }

class BusinessInventoryState extends Equatable {
  const BusinessInventoryState({
    this.status = BusinessInventoryStatus.initial,
    this.business,
    this.products = const [],
    this.costos = const {},
    this.message,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final BusinessInventoryStatus status;
  final BusinessModel? business;
  final List<ProductModel> products;
  final Map<String, BusinessProductCost> costos;
  final String? message;
  final bool hasMore;
  final bool isLoadingMore;

  BusinessInventoryState copyWith({
    BusinessInventoryStatus? status,
    BusinessModel? business,
    List<ProductModel>? products,
    Map<String, BusinessProductCost>? costos,
    String? message,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return BusinessInventoryState(
      status: status ?? this.status,
      business: business ?? this.business,
      products: products ?? this.products,
      costos: costos ?? this.costos,
      message: message,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    business,
    products,
    costos,
    message,
    hasMore,
    isLoadingMore,
  ];
}
