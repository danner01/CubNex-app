import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../../search/data/models/search_results_model.dart';
import 'properties_state.dart';

class PropertiesCubit extends Cubit<PropertiesState> {
  PropertiesCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const PropertiesState());

  final ApiClient _apiClient;

  Future<void> load({String? type}) async {
    emit(state.copyWith(status: PropertiesStatus.loading));
    final result = await _apiClient.get<List<SearchAssetModel>>(
      '/propiedades',
      queryParameters: {
        'limit': 80,
        'order': 'created_at.desc',
        if (type != null) 'tipo': 'eq.$type',
      },
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    SearchAssetModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PropertiesStatus.failure,
          message: result.error?.message ?? 'No se pudieron cargar propiedades.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PropertiesStatus.success,
        items: result.data ?? const [],
      ),
    );
  }

  Future<void> loadMine() async {
    emit(state.copyWith(status: PropertiesStatus.loading));
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
    final businessId = businessResult.data?.id;
    if (!businessResult.isSuccess || businessId == null) {
      emit(
        state.copyWith(
          status: PropertiesStatus.failure,
          message: businessResult.error?.message ?? 'No tienes negocio creado.',
        ),
      );
      return;
    }

    emit(state.copyWith(businessId: businessId));
    final result = await _apiClient.get<List<SearchAssetModel>>(
      '/propiedades',
      queryParameters: {
        'negocio_id': 'eq.$businessId',
        'limit': 80,
        'order': 'created_at.desc',
      },
      parser: _parseList,
    );
    _emitList(result);
  }

  Future<void> create({
    required String title,
    required String type,
    required double price,
    String currency = 'USD',
    String? description,
    String? province,
    String? municipality,
    double? latitude,
    double? longitude,
  }) async {
    final businessId = state.businessId;
    if (businessId == null) return;

    emit(state.copyWith(status: PropertiesStatus.saving));
    final result = await _apiClient.post<void>(
      '/propiedades',
      data: {
        'negocio_id': businessId,
        'tipo': type,
        'titulo': title,
        'descripcion': description,
        'precio': price,
        'moneda': currency,
        'provincia': province,
        'municipio': municipality,
        'coordenadas': latitude == null || longitude == null
            ? null
            : {'lat': latitude, 'lng': longitude},
        'operacion': type == 'alquiler' ? 'alquiler' : 'venta',
        'disponible': true,
      },
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PropertiesStatus.failure,
          message: result.error?.message ?? 'No se pudo publicar.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PropertiesStatus.success,
        message: 'Publicacion creada.',
      ),
    );
    await loadMine();
  }

  List<SearchAssetModel> _parseList(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => SearchAssetModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  void _emitList(dynamic result) {
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: PropertiesStatus.failure,
          message: result.error?.message ?? 'No se pudieron cargar propiedades.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: PropertiesStatus.success,
        items: result.data ?? const [],
      ),
    );
  }
}
