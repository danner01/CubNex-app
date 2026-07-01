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

    final statsResult = await _apiClient.get<Map<String, dynamic>?>(
      '/negocios/${business.id}/estadisticas',
      parser: (json) {
        if (json is List && json.isNotEmpty && json.first is Map) {
          return Map<String, dynamic>.from(json.first as Map);
        }
        if (json is Map) return Map<String, dynamic>.from(json);
        return null;
      },
    );

    final products = await _count('/negocios/${business.id}/productos');
    final reviews = await _count('/negocios/${business.id}/resenas');
    final promotions = await _count(
      '/promociones/mis-promociones',
      queryParameters: {'negocio_id': business.id},
    );
    final properties = await _count(
      '/propiedades',
      queryParameters: {'negocio_id': 'eq.${business.id}'},
    );
    final transport = await _count(
      '/transporte',
      queryParameters: {'negocio_id': 'eq.${business.id}'},
    );
    final menus = await _count('/menus/${business.id}');
    final stats = statsResult.data ?? const {};

    emit(
      state.copyWith(
        status: BusinessDashboardStatus.success,
        needsWizard: false,
        summary: BusinessDashboardSummary(
          business: business,
          products: products,
          reviews: reviews,
          promotions: promotions,
          properties: properties,
          transport: transport,
          menus: menus,
          points: _int(stats['puntos_acumulados']),
          sales: _int(stats['total_ventas']),
          level: '${stats['nivel'] ?? 'bronce'}',
        ),
      ),
    );
  }

  Future<BusinessModel?> _loadFallbackBusiness() async {
    final businessResult = await _apiClient.get<BusinessModel?>(
      '/negocios/mi-negocio',
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return BusinessModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        return null;
      },
    );

    if (!businessResult.isSuccess) return null;
    return businessResult.data;
  }

  Future<int> _count(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final result = await _apiClient.get<int>(
      path,
      queryParameters: {'limit': 100, ...?queryParameters},
      parser: (json) => json is List ? json.length : 0,
    );
    return result.data ?? 0;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }
}
