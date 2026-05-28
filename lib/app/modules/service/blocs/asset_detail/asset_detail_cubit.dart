import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/asset_detail_model.dart';
import 'asset_detail_state.dart';

class AssetDetailCubit extends Cubit<AssetDetailState> {
  AssetDetailCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const AssetDetailState());

  final ApiClient _apiClient;

  Future<void> load({
    required String id,
    required AssetDetailKind kind,
  }) async {
    emit(state.copyWith(status: AssetDetailStatus.loading));
    final path = switch (kind) {
      AssetDetailKind.property => '/propiedades/$id',
      AssetDetailKind.transport => '/transporte/$id',
    };

    final result = await _apiClient.get<AssetDetailModel?>(
      path,
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return AssetDetailModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
            kind: kind,
          );
        }
        if (json is Map) {
          return AssetDetailModel.fromJson(
            Map<String, dynamic>.from(json),
            kind: kind,
          );
        }
        return null;
      },
    );

    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: AssetDetailStatus.success,
          asset: result.data,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AssetDetailStatus.failure,
        message: result.error?.message ?? 'No se pudo cargar el detalle.',
      ),
    );
  }

  Future<void> submitRequest({
    required String contactName,
    String? phone,
    String? email,
    String? message,
  }) async {
    final asset = state.asset;
    if (asset == null || asset.businessId == null || asset.businessId!.isEmpty) {
      emit(
        state.copyWith(
          status: AssetDetailStatus.failure,
          message: 'Esta publicacion no tiene negocio asociado.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: AssetDetailStatus.saving));
    final result = await _apiClient.post<bool>(
      '/pedidos',
      data: {
        'negocio_id': asset.businessId,
        'tipo': asset.kind == AssetDetailKind.property ? 'propiedad' : 'transporte',
        if (asset.kind == AssetDetailKind.property) 'propiedad_id': asset.id,
        if (asset.kind == AssetDetailKind.transport) 'transporte_id': asset.id,
        'nombre_contacto': contactName,
        'telefono': phone,
        'email': email,
        'mensaje': message,
        'moneda': asset.currency ?? 'CUP',
        'total_estimado': asset.price ?? asset.basePrice,
        'origen': 'apk',
        'metadata': {
          'titulo': asset.title,
          'tipo_anuncio': asset.type,
        },
      },
      parser: (_) => true,
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: AssetDetailStatus.failure,
          message: result.error?.message ?? 'No se pudo enviar la solicitud.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AssetDetailStatus.success,
        message: 'Solicitud enviada al negocio.',
      ),
    );
  }
}
