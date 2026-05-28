import 'package:equatable/equatable.dart';

import '../../data/models/banner_model.dart';
import '../../data/models/business_model.dart';
import '../../data/models/product_model.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.banners = const [],
    this.businesses = const [],
    this.products = const [],
    this.errorMessage,
  });

  final HomeStatus status;
  final List<BannerModel> banners;
  final List<BusinessModel> businesses;
  final List<ProductModel> products;
  final String? errorMessage;

  HomeState copyWith({
    HomeStatus? status,
    List<BannerModel>? banners,
    List<BusinessModel>? businesses,
    List<ProductModel>? products,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      banners: banners ?? this.banners,
      businesses: businesses ?? this.businesses,
      products: products ?? this.products,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    banners,
    businesses,
    products,
    errorMessage,
  ];
}
