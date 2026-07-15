import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/business_operational_references.dart';
import '../../data/models/business_dashboard_summary.dart';
import 'business_dashboard_state.dart';

class BusinessDashboardCubit extends Cubit<BusinessDashboardState> {
  BusinessDashboardCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const BusinessDashboardState());

  final ApiClient _apiClient;

  Future<void> load({BusinessModel? selectedBusiness}) async {
    _safeEmit(state.copyWith(status: BusinessDashboardStatus.loading));
    try {
      final business = selectedBusiness ?? await _loadFallbackBusiness();
      if (isClosed) return;
      if (business == null) {
        final noBusiness = selectedBusiness == null;
        _safeEmit(
          state.copyWith(
            status: BusinessDashboardStatus.failure,
            message: 'No tienes negocio creado.',
            needsWizard: noBusiness,
          ),
        );
        return;
      }

      final baseSummary = BusinessDashboardSummary(business: business);
      final remoteRefs = await _loadOperationalReferences(
        business.businessParentCategory,
      );
      if (isClosed) return;
      _safeEmit(
        state.copyWith(
          status: BusinessDashboardStatus.success,
          needsWizard: false,
          summary: baseSummary,
          operationalReferences: remoteRefs,
          message: 'Cargando metricas...',
        ),
      );

      final stats = await _loadStats(business.id);
      if (isClosed) return;
      final counts = await Future.wait<int>([
        _count('/negocios/${business.id}/productos'),
        _count('/negocios/${business.id}/resenas'),
        _count(
          '/promociones/mis-promociones',
          queryParameters: {'negocio_id': business.id},
        ),
        _count(
          '/propiedades',
          queryParameters: {'negocio_id': 'eq.${business.id}'},
        ),
        _count(
          '/transporte',
          queryParameters: {'negocio_id': 'eq.${business.id}'},
        ),
        _count('/menus/${business.id}'),
      ]);
      if (isClosed) return;

      _safeEmit(
        state.copyWith(
          status: BusinessDashboardStatus.success,
          needsWizard: false,
          operationalReferences: remoteRefs,
          summary: baseSummary.copyWith(
            products: counts[0],
            reviews: counts[1],
            promotions: counts[2],
            properties: counts[3],
            transport: counts[4],
            menus: counts[5],
            points: _int(stats['puntos_acumulados']),
            sales: _int(stats['total_ventas']),
            level: '${stats['nivel'] ?? 'bronce'}',
          ),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      final business = selectedBusiness;
      if (business != null) {
        _safeEmit(
          state.copyWith(
            status: BusinessDashboardStatus.success,
            needsWizard: false,
            summary: BusinessDashboardSummary(business: business),
            message:
                'Algunas estadisticas demoraron demasiado. Mostramos el panel basico.',
          ),
        );
        return;
      }
      _safeEmit(
        state.copyWith(
          status: BusinessDashboardStatus.failure,
          message: 'No se pudo cargar el panel de negocio.',
        ),
      );
    }
  }

  void _safeEmit(BusinessDashboardState nextState) {
    if (!isClosed) emit(nextState);
  }

  Future<Map<String, dynamic>> _loadStats(String businessId) async {
    try {
      final statsResult = await _apiClient
          .get<Map<String, dynamic>?>(
            '/negocios/$businessId/estadisticas',
            parser: (json) {
              if (json is List && json.isNotEmpty && json.first is Map) {
                return Map<String, dynamic>.from(json.first as Map);
              }
              if (json is Map) return Map<String, dynamic>.from(json);
              return null;
            },
          )
          .timeout(const Duration(seconds: 8));
      return statsResult.data ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<BusinessModel?> _loadFallbackBusiness() async {
    final businessResult = await _apiClient
        .get<BusinessModel?>(
          '/negocios/mi-negocio',
          parser: (json) {
            if (json is List && json.isNotEmpty) {
              return BusinessModel.fromJson(
                Map<String, dynamic>.from(json.first as Map),
              );
            }
            if (json is Map) {
              return BusinessModel.fromJson(Map<String, dynamic>.from(json));
            }
            return null;
          },
        )
        .timeout(const Duration(seconds: 10));

    if (!businessResult.isSuccess) return null;
    return businessResult.data;
  }

  Future<BusinessOperationalReferences?> _loadOperationalReferences(
    String? category,
  ) async {
    try {
      final result = await _apiClient
          .get<BusinessOperationalReferences?>(
            '/configuracion/dashboard-operativo',
            queryParameters: {
              if (category != null && category.isNotEmpty) 'categoria': category,
            },
            parser: (json) => _parseOperationalReferences(json, category),
          )
          .timeout(const Duration(seconds: 5));
      return result.data;
    } catch (_) {
      return null;
    }
  }

  BusinessOperationalReferences? _parseOperationalReferences(
    dynamic json,
    String? category,
  ) {
    if (json is! Map) return null;
    final payload = Map<String, dynamic>.from(json);

    Map<String, dynamic>? source;
    if (payload['referencias'] is Map) {
      source = Map<String, dynamic>.from(payload['referencias'] as Map);
    } else {
      source = payload;
    }

    if (category != null && category.isNotEmpty && source[category] is Map) {
      source = Map<String, dynamic>.from(source[category] as Map);
    }

    final sales = _int(source['ventas_ref'] ?? source['ventas'] ?? source['sales']);
    final products = _int(
      source['productos_ref'] ?? source['productos'] ?? source['products'],
    );
    final reviews = _int(source['resenas_ref'] ?? source['resenas'] ?? source['reviews']);
    final promotions = _int(
      source['promos_ref'] ?? source['promociones'] ?? source['promos'],
    );

    if (sales <= 0 && products <= 0 && reviews <= 0 && promotions <= 0) {
      return null;
    }

    return BusinessOperationalReferences(
      sales: sales > 0 ? sales : 50000,
      products: products > 0 ? products : 80,
      reviews: reviews > 0 ? reviews : 40,
      promotions: promotions > 0 ? promotions : 12,
    );
  }

  Future<int> _count(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final result = await _apiClient
          .get<int>(
            path,
            queryParameters: {'limit': 100, ...?queryParameters},
            parser: (json) => json is List ? json.length : 0,
          )
          .timeout(const Duration(seconds: 8));
      return result.data ?? 0;
    } catch (_) {
      return 0;
    }
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }
}
