import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/entities/employee_permissions.dart';
import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../../plans/data/models/plan_status.dart';
import '../../data/models/business_operational_references.dart';
import '../../data/models/business_dashboard_summary.dart';
import '../../data/models/business_opportunity.dart';
import 'business_dashboard_state.dart';

class BusinessDashboardCubit extends Cubit<BusinessDashboardState> {
  BusinessDashboardCubit({
    required ApiClient apiClient,
    required SharedPreferences sharedPreferences,
  }) : _apiClient = apiClient,
       _prefs = sharedPreferences,
       super(const BusinessDashboardState());

  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  Future<void> load({BusinessModel? selectedBusiness}) async {
    _safeEmit(
      BusinessDashboardState(
        status: BusinessDashboardStatus.loading,
        nearbyStatus: NearbyOpportunityStatus.loading,
        canViewReports: selectedBusiness?.canEmployee(
              EmployeePermissionKeys.verReportes,
            ) ??
            true,
      ),
    );
    try {
      final business = selectedBusiness ?? await _loadFallbackBusiness();
      if (isClosed) return;
      if (business == null) {
        _safeEmit(
          state.copyWith(
            status: BusinessDashboardStatus.failure,
            message: 'No tienes negocio creado.',
            needsWizard: selectedBusiness == null,
            canViewReports: false,
          ),
        );
        return;
      }

      final canViewReports = business.canEmployee(
        EmployeePermissionKeys.verReportes,
      );
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
          canViewReports: canViewReports,
          nearbyStatus: NearbyOpportunityStatus.loading,
          message: 'Cargando metricas...',
        ),
      );

      final stats = canViewReports
          ? await _loadStats(business.id)
          : const <String, dynamic>{};
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

      final values = await Future.wait([
        _loadActivePlan(business.id),
        canViewReports
            ? _loadOpportunityMetrics(business.id)
            : Future.value(const <String, dynamic>{}),
        _loadNearbyOpportunities(),
        _loadAllianceOpportunities(business.id),
      ]);
      if (isClosed) return;
      final activePlan = values[0] as ActiveSubscription?;
      final opportunityMetrics = values[1] as Map<String, dynamic>;
      final nearby = values[2] as _NearbyResult;
      final alliances = values[3] as List<BusinessOpportunity>;
      final merged = _mergeOpportunities(nearby.items, alliances);
      final activity = opportunityMetrics['actividad_agregada'];
      final activityMap = activity is Map ? Map<String, dynamic>.from(activity) : const <String, dynamic>{};
      final summary = baseSummary.copyWith(
        products: counts[0],
        reviews: counts[1],
        promotions: counts[2],
        properties: counts[3],
        transport: counts[4],
        menus: counts[5],
        points: _int(stats['puntos_acumulados']),
        sales: _int(stats['total_ventas']),
        orders: _int(stats['total_pedidos'] ?? stats['total_reservas']),
        subscribers: _int(
          opportunityMetrics['suscriptores_total'] ?? stats['suscriptores'],
        ),
        potentialCustomers: _int(
          opportunityMetrics['demanda_potencial_total'] ??
              stats['clientes_potenciales'],
        ),
        recentSubscribers: _int(activityMap['nuevos_30d']),
        notifiedSubscribers: _int(
          opportunityMetrics['suscriptores_con_notificaciones'] ??
              activityMap['con_avisos'],
        ),
        level: '${stats['nivel'] ?? 'bronce'}',
      );
      final trends = _rememberTrends(business.id, summary);

      _safeEmit(
        state.copyWith(
          status: BusinessDashboardStatus.success,
          needsWizard: false,
          operationalReferences: remoteRefs,
          activePlan: activePlan,
          nearbyOpportunities: merged,
          nearbyStatus: merged.isNotEmpty
              ? NearbyOpportunityStatus.ready
              : nearby.status,
          nearbyMessage: nearby.message,
          metricTrends: trends,
          canViewReports: canViewReports,
          summary: summary,
          message: null,
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
            canViewReports: business.canEmployee(
              EmployeePermissionKeys.verReportes,
            ),
            summary: BusinessDashboardSummary(business: business),
            nearbyStatus: NearbyOpportunityStatus.empty,
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

  Future<void> interactWithOpportunity({
    required String businessId,
    required String action,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>?>(
      '/oportunidades/interacciones',
      data: {'negocio_id': businessId, 'accion': action},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : null,
    );
    if (!result.isSuccess) return;
    final next = [...state.nearbyOpportunities];
    if (action == 'descartar') {
      next.removeWhere((item) => item.businessId == businessId);
    } else {
      final index = next.indexWhere((item) => item.businessId == businessId);
      if (index >= 0) {
        next[index] = next[index].copyWith(saved: true, kind: 'alianza');
      }
    }
    _safeEmit(
      state.copyWith(
        nearbyOpportunities: next,
        nearbyStatus: next.isEmpty
            ? NearbyOpportunityStatus.empty
            : NearbyOpportunityStatus.ready,
      ),
    );
  }

  void _safeEmit(BusinessDashboardState nextState) {
    if (!isClosed) emit(nextState);
  }

  Future<ActiveSubscription?> _loadActivePlan(String businessId) async {
    try {
      final result = await _apiClient
          .get<PlanStatus?>(
            '/suscripciones/solicitudes-plan',
            parser: (json) => json is Map
                ? PlanStatus.fromJson(Map<String, dynamic>.from(json))
                : null,
          )
          .timeout(const Duration(seconds: 8));
      return result.data?.activeFor(businessId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _loadOpportunityMetrics(String businessId) async {
    try {
      final result = await _apiClient
          .get<Map<String, dynamic>?>(
            '/oportunidades/negocios/$businessId/metricas',
            parser: (json) => json is Map ? Map<String, dynamic>.from(json) : null,
          )
          .timeout(const Duration(seconds: 8));
      return result.data ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<_NearbyResult> _loadNearbyOpportunities() async {
    try {
      final result = await _apiClient
          .get<List<BusinessOpportunity>>(
            '/oportunidades/cercanas',
            parser: (json) {
              if (json is! List) return const [];
              return json
                  .whereType<Map>()
                  .map((item) => BusinessOpportunity.fromJson(Map<String, dynamic>.from(item)))
                  .where((item) => item.businessId.isNotEmpty)
                  .toList();
            },
          )
          .timeout(const Duration(seconds: 8));
      if (result.error?.code == 'UBICACION_SIN_OPT_IN' || result.error?.statusCode == 403) {
        return const _NearbyResult(
          status: NearbyOpportunityStatus.needsLocation,
          message: 'Activa usar ubicacion para sugerencias en Perfil > Preferencias.',
        );
      }
      if (!result.isSuccess) {
        return _NearbyResult(
          status: NearbyOpportunityStatus.empty,
          message: result.error?.message ?? 'No se pudieron cargar oportunidades cercanas.',
        );
      }
      final items = result.data ?? const <BusinessOpportunity>[];
      return _NearbyResult(
        items: items,
        status: items.isEmpty ? NearbyOpportunityStatus.empty : NearbyOpportunityStatus.ready,
        message: items.isEmpty
            ? 'No hay oportunidades cerca con demanda agregada suficiente.'
            : null,
      );
    } catch (_) {
      return const _NearbyResult(
        status: NearbyOpportunityStatus.empty,
        message: 'No se pudieron cargar oportunidades cercanas.',
      );
    }
  }

  Future<List<BusinessOpportunity>> _loadAllianceOpportunities(String businessId) async {
    try {
      final result = await _apiClient
          .get<List<BusinessOpportunity>>(
            '/red-negocios/oportunidades',
            queryParameters: {'negocio_id': businessId, 'limit': 12},
            parser: (json) {
              final list = json is Map && json['oportunidades'] is List
                  ? json['oportunidades'] as List
                  : json is List
                      ? json
                      : const [];
              return list
                  .whereType<Map>()
                  .map((item) => BusinessOpportunity.fromJson(Map<String, dynamic>.from(item)))
                  .where((item) => item.businessId.isNotEmpty)
                  .map((item) => item.copyWith(
                        kind: item.kind == 'comprar' || item.kind == 'vender'
                            ? 'complementario'
                            : item.kind,
                      ))
                  .toList();
            },
          )
          .timeout(const Duration(seconds: 8));
      return result.data ?? const [];
    } catch (_) {
      return const [];
    }
  }

  List<BusinessOpportunity> _mergeOpportunities(
    List<BusinessOpportunity> nearby,
    List<BusinessOpportunity> alliances,
  ) {
    final seen = <String>{};
    final merged = <BusinessOpportunity>[];
    for (final item in [...nearby, ...alliances]) {
      if (item.businessId.isEmpty || seen.contains(item.businessId)) continue;
      seen.add(item.businessId);
      merged.add(item);
    }
    return merged;
  }

  Map<String, int> _rememberTrends(String businessId, BusinessDashboardSummary summary) {
    final key = 'dashboard.snapshot.$businessId';
    final previousRaw = _prefs.getString(key);
    final previous = previousRaw == null
        ? const <String, dynamic>{}
        : jsonDecode(previousRaw) as Map<String, dynamic>;
    int trend(String metric, int current) {
      final old = _int(previous[metric]);
      if (old <= 0 || old == current) return 0;
      return current > old ? 1 : -1;
    }

    final trends = {
      'sales': trend('sales', summary.sales),
      'orders': trend('orders', summary.orders),
      'reviews': trend('reviews', summary.reviews),
      'subscribers': trend('subscribers', summary.subscribers),
      'potential': trend('potential', summary.potentialCustomers),
      'conversion': trend('conversion', summary.conversionPercent),
    };
    _prefs.setString(
      key,
      jsonEncode({
        'sales': summary.sales,
        'orders': summary.orders,
        'reviews': summary.reviews,
        'subscribers': summary.subscribers,
        'potential': summary.potentialCustomers,
        'conversion': summary.conversionPercent,
      }),
    );
    return trends;
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
              return BusinessModel.fromJson(Map<String, dynamic>.from(json.first as Map));
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

  Future<BusinessOperationalReferences?> _loadOperationalReferences(String? category) async {
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

  BusinessOperationalReferences? _parseOperationalReferences(dynamic json, String? category) {
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
    final products = _int(source['productos_ref'] ?? source['productos'] ?? source['products']);
    final reviews = _int(source['resenas_ref'] ?? source['resenas'] ?? source['reviews']);
    final promotions = _int(source['promos_ref'] ?? source['promociones'] ?? source['promos']);
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

  Future<int> _count(String path, {Map<String, dynamic>? queryParameters}) async {
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

class _NearbyResult {
  const _NearbyResult({
    this.items = const [],
    required this.status,
    this.message,
  });

  final List<BusinessOpportunity> items;
  final NearbyOpportunityStatus status;
  final String? message;
}
