import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/business_dashboard_summary.dart';
import 'business_dashboard_state.dart';

class BusinessDashboardCubit extends Cubit<BusinessDashboardState> {
  BusinessDashboardCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const BusinessDashboardState());

  final ApiClient _apiClient;

  Future<void> load({BusinessModel? selectedBusiness}) async {
    emit(state.copyWith(status: BusinessDashboardStatus.loading));
    try {
      final business = selectedBusiness ?? await _loadFallbackBusiness();
      if (business == null) {
        final noBusiness = selectedBusiness == null;
        emit(
          state.copyWith(
            status: BusinessDashboardStatus.failure,
            message: 'No tienes negocio creado.',
            needsWizard: noBusiness,
          ),
        );
        return;
      }

      final stats = await _loadStats(business.id);
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

      emit(
        state.copyWith(
          status: BusinessDashboardStatus.success,
          needsWizard: false,
          summary: BusinessDashboardSummary(
            business: business,
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
      final business = selectedBusiness;
      if (business != null) {
        emit(
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
      emit(
        state.copyWith(
          status: BusinessDashboardStatus.failure,
          message: 'No se pudo cargar el panel de negocio.',
        ),
      );
    }
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
