import 'package:equatable/equatable.dart';

import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';
import '../../../business/data/models/store_customization_model.dart';
import '../../../review_rating/data/models/review_model.dart';

enum BusinessDetailStatus { initial, loading, success, failure, saving }

class BusinessDetailState extends Equatable {
  const BusinessDetailState({
    this.status = BusinessDetailStatus.initial,
    this.business,
    this.customization,
    this.products = const [],
    this.reviews = const [],
    this.errorMessage,
    this.message,
  });

  final BusinessDetailStatus status;
  final BusinessModel? business;
  final StoreCustomizationModel? customization;
  final List<ProductModel> products;
  final List<ReviewModel> reviews;
  final String? errorMessage;
  final String? message;

  BusinessDetailState copyWith({
    BusinessDetailStatus? status,
    BusinessModel? business,
    StoreCustomizationModel? customization,
    List<ProductModel>? products,
    List<ReviewModel>? reviews,
    String? errorMessage,
    String? message,
  }) {
    return BusinessDetailState(
      status: status ?? this.status,
      business: business ?? this.business,
      customization: customization ?? this.customization,
      products: products ?? this.products,
      reviews: reviews ?? this.reviews,
      errorMessage: errorMessage,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    business,
    customization,
    products,
    reviews,
    errorMessage,
    message,
  ];
}
