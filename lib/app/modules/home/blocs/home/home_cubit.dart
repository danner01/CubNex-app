import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../data/models/banner_model.dart';
import '../../data/models/business_model.dart';
import '../../data/models/product_model.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const HomeState());

  final ApiClient _apiClient;
  static const _pageSize = 10;

  Future<void> loadHome() async {
    if (isClosed) return;
    emit(state.copyWith(status: HomeStatus.loading, errorMessage: null));

    final results =
        await Future.wait([
          _loadBanners(),
          _loadBusinesses(),
          _loadProducts(),
        ]).timeout(
          const Duration(seconds: 7),
          onTimeout: () => [
            _HomeLoadResult<List<BannerModel>>.fallback(const []),
            _HomeLoadResult<List<BusinessModel>>.fallback(const []),
            _HomeLoadResult<List<ProductModel>>.fallback(const []),
          ],
        );

    if (isClosed) return;

    final bannersResult = results[0] as _HomeLoadResult<List<BannerModel>>;
    final businessesResult = results[1] as _HomeLoadResult<List<BusinessModel>>;
    final productsResult = results[2] as _HomeLoadResult<List<ProductModel>>;
    final warnings = [
      bannersResult.message,
      businessesResult.message,
      productsResult.message,
    ].whereType<String>().toList();
    final warning = warnings.isEmpty ? null : warnings.first;

    emit(
      state.copyWith(
        status: HomeStatus.success,
        banners: bannersResult.data,
        businesses: businessesResult.data,
        products: productsResult.data,
        businessOffset: businessesResult.data.length,
        productOffset: productsResult.data.length,
        hasMoreBusinesses: businessesResult.data.length >= _pageSize,
        hasMoreProducts: productsResult.data.length >= _pageSize,
        loadingMoreBusinesses: false,
        loadingMoreProducts: false,
        errorMessage: warning,
      ),
    );
  }

  Future<void> loadMoreBusinesses() async {
    if (isClosed || state.loadingMoreBusinesses || !state.hasMoreBusinesses) {
      return;
    }

    final offset = state.businessOffset;
    emit(state.copyWith(loadingMoreBusinesses: true, errorMessage: null));
    final result = await _loadBusinesses(offset: offset);
    if (isClosed) return;

    final next = result.data;
    emit(
      state.copyWith(
        loadingMoreBusinesses: false,
        businesses: [...state.businesses, ...next],
        businessOffset: state.businessOffset + next.length,
        hasMoreBusinesses: next.length >= _pageSize,
        errorMessage: result.message,
      ),
    );
  }

  Future<void> loadMoreProducts() async {
    if (isClosed || state.loadingMoreProducts || !state.hasMoreProducts) {
      return;
    }

    final offset = state.productOffset;
    emit(state.copyWith(loadingMoreProducts: true, errorMessage: null));
    final result = await _loadProducts(offset: offset);
    if (isClosed) return;

    final next = result.data;
    emit(
      state.copyWith(
        loadingMoreProducts: false,
        products: [...state.products, ...next],
        productOffset: state.productOffset + next.length,
        hasMoreProducts: next.length >= _pageSize,
        errorMessage: result.message,
      ),
    );
  }

  Future<_HomeLoadResult<List<BannerModel>>> _loadBanners() async {
    final result = await _apiClient.get<List<BannerModel>>(
      '/banners',
      queryParameters: {'limit': 5},
      parser: (json) =>
          _asList(json).map((item) => BannerModel.fromJson(item)).toList(),
    );
    return _HomeLoadResult.fromApi(result, fallback: const []);
  }

  Future<_HomeLoadResult<List<BusinessModel>>> _loadBusinesses({
    int offset = 0,
  }) async {
    final result = await _apiClient.get<List<BusinessModel>>(
      '/negocios',
      queryParameters: {
        'limit': _pageSize,
        'offset': offset,
        'order': 'created_at.desc',
      },
      parser: (json) =>
          _asList(json).map((item) => BusinessModel.fromJson(item)).toList(),
    );
    return _HomeLoadResult.fromApi(result, fallback: const []);
  }

  Future<_HomeLoadResult<List<ProductModel>>> _loadProducts({
    int offset = 0,
  }) async {
    final result = await _apiClient.get<List<ProductModel>>(
      '/productos/destacados',
      queryParameters: {'limit': _pageSize, 'offset': offset},
      parser: (json) =>
          _asList(json).map((item) => ProductModel.fromJson(item)).toList(),
    );
    return _HomeLoadResult.fromApi(result, fallback: const []);
  }

  List<Map<String, dynamic>> _asList(dynamic json) {
    if (json is List) {
      return json
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return const [];
  }
}

class _HomeLoadResult<T> {
  const _HomeLoadResult({required this.data, this.message});
  const _HomeLoadResult.fallback(this.data)
    : message =
          'La conexion esta lenta. Te mostramos contenido base mientras cargan los datos reales.';

  factory _HomeLoadResult.fromApi(ApiResult<T> result, {required T fallback}) {
    if (result.isSuccess && result.data != null) {
      return _HomeLoadResult(data: result.data as T);
    }

    return _HomeLoadResult(
      data: fallback,
      message:
          result.error?.message ??
          'No se pudieron cargar algunos datos. Intenta actualizar.',
    );
  }

  final T data;
  final String? message;
}
