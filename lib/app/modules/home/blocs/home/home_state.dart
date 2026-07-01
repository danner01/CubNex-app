import 'package:equatable/equatable.dart';

import '../../data/models/banner_model.dart';
import '../../data/models/business_model.dart';
import '../../data/models/product_model.dart';
import '../../../jobs/data/models/job_model.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.banners = const [],
    this.businesses = const [],
    this.products = const [],
    this.jobs = const [],
    this.errorMessage,
    this.loadingMoreBusinesses = false,
    this.loadingMoreProducts = false,
    this.hasMoreBusinesses = true,
    this.hasMoreProducts = true,
    this.businessOffset = 0,
    this.productOffset = 0,
  });

  final HomeStatus status;
  final List<BannerModel> banners;
  final List<BusinessModel> businesses;
  final List<ProductModel> products;
  final List<JobModel> jobs;
  final String? errorMessage;
  final bool loadingMoreBusinesses;
  final bool loadingMoreProducts;
  final bool hasMoreBusinesses;
  final bool hasMoreProducts;
  final int businessOffset;
  final int productOffset;

  HomeState copyWith({
    HomeStatus? status,
    List<BannerModel>? banners,
    List<BusinessModel>? businesses,
    List<ProductModel>? products,
    List<JobModel>? jobs,
    String? errorMessage,
    bool? loadingMoreBusinesses,
    bool? loadingMoreProducts,
    bool? hasMoreBusinesses,
    bool? hasMoreProducts,
    int? businessOffset,
    int? productOffset,
  }) {
    return HomeState(
      status: status ?? this.status,
      banners: banners ?? this.banners,
      businesses: businesses ?? this.businesses,
      products: products ?? this.products,
      jobs: jobs ?? this.jobs,
      errorMessage: errorMessage,
      loadingMoreBusinesses:
          loadingMoreBusinesses ?? this.loadingMoreBusinesses,
      loadingMoreProducts: loadingMoreProducts ?? this.loadingMoreProducts,
      hasMoreBusinesses: hasMoreBusinesses ?? this.hasMoreBusinesses,
      hasMoreProducts: hasMoreProducts ?? this.hasMoreProducts,
      businessOffset: businessOffset ?? this.businessOffset,
      productOffset: productOffset ?? this.productOffset,
    );
  }

  @override
  List<Object?> get props => [
    status,
    banners,
    businesses,
    products,
    jobs,
    errorMessage,
    loadingMoreBusinesses,
    loadingMoreProducts,
    hasMoreBusinesses,
    hasMoreProducts,
    businessOffset,
    productOffset,
  ];
}
