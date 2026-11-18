import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../../../common/services/json_cache.dart';
import '../../data/models/banner_model.dart';
import '../../data/models/business_model.dart';
import '../../data/models/product_model.dart';
import '../../../jobs/data/models/job_model.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const HomeState());

  final ApiClient _apiClient;
  static const _pageSize = 10;

  Future<void> loadHome() async {
    if (isClosed) return;
    final hadData = state.businesses.isNotEmpty || state.products.isNotEmpty;
    if (!hadData) {
      final cached = await _readCache();
      if (isClosed) return;
      if (cached != null) {
        emit(cached);
      } else {
        emit(state.copyWith(status: HomeStatus.loading, errorMessage: null));
      }
    } else {
      emit(state.copyWith(status: HomeStatus.loading, errorMessage: null));
    }

    final results =
        await Future.wait([
          _loadBanners(),
          _loadBusinesses(),
          _loadProducts(),
          _loadJobs(),
        ]).timeout(
          const Duration(seconds: 7),
          onTimeout: () => [
            _HomeLoadResult<List<BannerModel>>.fallback(const []),
            _HomeLoadResult<List<BusinessModel>>.fallback(const []),
            _HomeLoadResult<List<ProductModel>>.fallback(const []),
            _HomeLoadResult<List<JobModel>>.fallback(const []),
          ],
        );

    if (isClosed) return;

    final bannersResult = results[0] as _HomeLoadResult<List<BannerModel>>;
    final businessesResult = results[1] as _HomeLoadResult<List<BusinessModel>>;
    final productsResult = results[2] as _HomeLoadResult<List<ProductModel>>;
    final jobsResult = results[3] as _HomeLoadResult<List<JobModel>>;
    final warnings = [
      bannersResult.message,
      businessesResult.message,
      productsResult.message,
      jobsResult.message,
    ].whereType<String>().toList();
    final warning = warnings.isEmpty ? null : warnings.first;

    // Si la red falla, se conserva lo mostrado desde la cache.
    List<T> pick<T>(_HomeLoadResult<List<T>> r, List<T> current) =>
        r.data.isEmpty && r.message != null && current.isNotEmpty
        ? current
        : r.data;
    final banners = pick(bannersResult, state.banners);
    final businesses = pick(businessesResult, state.businesses);
    final products = pick(productsResult, state.products);
    final jobs = pick(jobsResult, state.jobs);

    emit(
      state.copyWith(
        status: HomeStatus.success,
        banners: banners,
        businesses: businesses,
        products: products,
        jobs: jobs,
        businessOffset: businesses.length,
        productOffset: products.length,
        hasMoreBusinesses: businesses.length >= _pageSize,
        hasMoreProducts: products.length >= _pageSize,
        loadingMoreBusinesses: false,
        loadingMoreProducts: false,
        errorMessage: warning,
      ),
    );
  }

  Future<HomeState?> _readCache() async {
    try {
      final banners = await JsonCache.read('home:banners');
      final businesses = await JsonCache.read('home:businesses');
      final products = await JsonCache.read('home:products');
      if (businesses == null && products == null) return null;
      final b = _parseList(businesses, BusinessModel.fromJson);
      final p = _parseList(products, ProductModel.fromJson);
      return state.copyWith(
        status: HomeStatus.success,
        banners: _parseList(banners, BannerModel.fromJson),
        businesses: b,
        products: p,
        businessOffset: b.length,
        productOffset: p.length,
        hasMoreBusinesses: b.length >= _pageSize,
        hasMoreProducts: p.length >= _pageSize,
        errorMessage: null,
      );
    } catch (_) {
      return null;
    }
  }

  List<T> _parseList<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
  ) => _asList(json).map(fromJson).toList();

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
      parser: (json) {
        if (json is List) JsonCache.save('home:banners', json);
        return _asList(json).map((item) => BannerModel.fromJson(item)).toList();
      },
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
      parser: (json) {
        if (offset == 0 && json is List) JsonCache.save('home:businesses', json);
        return _asList(json)
            .map((item) => BusinessModel.fromJson(item))
            .toList();
      },
    );
    return _HomeLoadResult.fromApi(result, fallback: const []);
  }

  Future<_HomeLoadResult<List<ProductModel>>> _loadProducts({
    int offset = 0,
  }) async {
    final result = await _apiClient.get<List<ProductModel>>(
      '/productos/recomendados',
      queryParameters: {'limit': _pageSize, 'offset': offset},
      parser: (json) {
        if (offset == 0 && json is List) JsonCache.save('home:products', json);
        return _asList(json).map((item) => ProductModel.fromJson(item)).toList();
      },
    );
    return _HomeLoadResult.fromApi(result, fallback: const []);
  }

  Future<_HomeLoadResult<List<JobModel>>> _loadJobs() async {
    final result = await _apiClient.get<List<JobModel>>(
      '/empleos',
      queryParameters: {'limit': 6, 'order': 'created_at.desc'},
      parser: (json) =>
          _asList(json).map((item) => JobModel.fromJson(item)).toList(),
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
