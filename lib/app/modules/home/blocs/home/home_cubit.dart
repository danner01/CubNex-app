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

  Future<void> loadHome() async {
    emit(state.copyWith(status: HomeStatus.loading, errorMessage: null));

    final results = await Future.wait([
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
        errorMessage: warning,
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

  Future<_HomeLoadResult<List<BusinessModel>>> _loadBusinesses() async {
    final result = await _apiClient.get<List<BusinessModel>>(
      '/negocios',
      queryParameters: {'limit': 10, 'order': 'created_at.desc'},
      parser: (json) =>
          _asList(json).map((item) => BusinessModel.fromJson(item)).toList(),
    );
    return _HomeLoadResult.fromApi(result, fallback: const []);
  }

  Future<_HomeLoadResult<List<ProductModel>>> _loadProducts() async {
    final result = await _apiClient.get<List<ProductModel>>(
      '/productos/destacados',
      queryParameters: {'limit': 10},
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

  factory _HomeLoadResult.fromApi(
    ApiResult<T> result, {
    required T fallback,
  }) {
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
