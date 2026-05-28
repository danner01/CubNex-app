import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/business_model.dart';
import '../../../search/data/models/search_results_model.dart';
import 'transport_state.dart';

class TransportCubit extends Cubit<TransportState> {
  TransportCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const TransportState());

  final ApiClient _apiClient;

  Future<void> load({String? type}) async {
    emit(state.copyWith(status: TransportStatus.loading));
    final result = await _apiClient.get<List<SearchAssetModel>>(
      '/transporte',
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
          status: TransportStatus.failure,
          message: result.error?.message ?? 'No se pudo cargar transporte.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TransportStatus.success,
        items: result.data ?? const [],
      ),
    );
  }

  Future<void> loadMine() async {
    emit(state.copyWith(status: TransportStatus.loading));
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
          status: TransportStatus.failure,
          message: businessResult.error?.message ?? 'No tienes negocio creado.',
        ),
      );
      return;
    }

    emit(state.copyWith(businessId: businessId));
    final result = await _apiClient.get<List<SearchAssetModel>>(
      '/transporte',
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
    String? description,
    String? vehicleType,
    double? basePrice,
    double? pricePerKm,
    String currency = 'CUP',
    double? latitude,
    double? longitude,
  }) async {
    final businessId = state.businessId;
    if (businessId == null) return;

    emit(state.copyWith(status: TransportStatus.saving));
    final result = await _apiClient.post<void>(
      '/transporte',
      data: {
        'negocio_id': businessId,
        'tipo': type,
        'titulo': title,
        'descripcion': description,
        'vehiculo_tipo': vehicleType,
        'precio_base': basePrice,
        'precio_por_km': pricePerKm,
        'cobertura_zonas': latitude == null || longitude == null
            ? null
            : {
                'punto_base': {'lat': latitude, 'lng': longitude},
              },
        'moneda': currency,
        'disponible': true,
      },
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: TransportStatus.failure,
          message: result.error?.message ?? 'No se pudo publicar transporte.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TransportStatus.success,
        message: 'Servicio publicado.',
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
          status: TransportStatus.failure,
          message: result.error?.message ?? 'No se pudo cargar transporte.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TransportStatus.success,
        items: result.data ?? const [],
      ),
    );
  }
}
