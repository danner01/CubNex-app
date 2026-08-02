import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/services/credit_service.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../business/data/models/store_customization_model.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';
import '../../../review_rating/data/models/review_model.dart';
import 'business_detail_state.dart';

class BusinessDetailCubit extends Cubit<BusinessDetailState> {
  BusinessDetailCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const BusinessDetailState());

  final ApiClient _apiClient;
  String? _businessId;

  Future<void> load(String id) async {
    _businessId = id;
    emit(state.copyWith(status: BusinessDetailStatus.loading));

    final businessFuture = _apiClient.get<BusinessModel?>(
      '/negocios/$id',
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
    );
    final productsFuture = _apiClient.get<List<ProductModel>>(
      '/negocios/$id/productos',
      queryParameters: {'limit': 24, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    ProductModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );
    final reviewsFuture = _apiClient.get<List<ReviewModel>>(
      '/negocios/$id/resenas',
      queryParameters: {'limit': 20, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
        return const [];
      },
    );

    final businessResult = await businessFuture;
    final customizationFuture = _apiClient.get<StoreCustomizationModel?>(
      '/personalizacion/$id',
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return StoreCustomizationModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        if (json is Map && json.isNotEmpty) {
          return StoreCustomizationModel.fromJson(
            Map<String, dynamic>.from(json),
          );
        }
        return null;
      },
    );
    final productsResult = await productsFuture;
    final reviewsResult = await reviewsFuture;
    final customizationResult = await customizationFuture;

    if (businessResult.isSuccess && businessResult.data != null) {
      final business = businessResult.data!;
      emit(
        state.copyWith(
          status: BusinessDetailStatus.success,
          business: business,
          customization:
              customizationResult.data ??
              StoreCustomizationModel.fromBusinessColors(
                businessId: business.id,
                colors: business.colors,
              ),
          products: productsResult.data ?? const [],
          reviews: reviewsResult.data ?? const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessDetailStatus.failure,
        errorMessage:
            businessResult.error?.message ?? 'No se pudo cargar la tienda.',
      ),
    );
  }

  Future<void> createReview({required int rating, String? comment}) async {
    final businessId = _businessId ?? state.business?.id;
    if (businessId == null) return;

    emit(state.copyWith(status: BusinessDetailStatus.saving));
    final result = await _apiClient.post<void>(
      '/resenas',
      data: {
        'negocio_id': businessId,
        'calificacion': rating,
        'comentario': comment,
        'activo': true,
      },
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessDetailStatus.success,
          message: result.error?.message ?? 'No se pudo publicar la resena.',
        ),
      );
      return;
    }
 
    await sl<CreditService>().recordBusinessReview(businessId);
    emit(
      state.copyWith(
        status: BusinessDetailStatus.success,
        message: 'Resena publicada.',
      ),
    );
    await load(businessId);
  }

  Future<void> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    final businessId = _businessId ?? state.business?.id;
    if (businessId == null) return;

    emit(state.copyWith(status: BusinessDetailStatus.saving));
    final result = await _apiClient.put<void>(
      '/resenas/$reviewId',
      data: {'calificacion': rating, 'comentario': comment, 'activo': true},
      parser: (_) {},
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessDetailStatus.success,
          message: result.error?.message ?? 'No se pudo editar la resena.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessDetailStatus.success,
        message: 'Resena actualizada.',
      ),
    );
    await load(businessId);
  }

  Future<void> markUseful(String reviewId) async {
    final result = await _apiClient.post<void>(
      '/resenas/$reviewId/util',
      data: const {},
      parser: (_) {},
    );
    if (result.isSuccess && _businessId != null) {
      await load(_businessId!);
    }
  }

  Future<void> connectBusiness({
    required String sourceBusinessId,
    required String targetBusinessId,
    required String relationType,
    required bool notifications,
    required List<String> productsOfInterest,
    String? notes,
  }) async {
    emit(state.copyWith(status: BusinessDetailStatus.saving));
    final result = await _apiClient.post<void>(
      '/red-negocios/conectar/$targetBusinessId',
      data: {
        'negocio_id': sourceBusinessId,
        'tipo_relacion': relationType,
        'notificaciones': notifications,
        'productos_interes': productsOfInterest,
        if (notes?.trim().isNotEmpty == true) 'notas': notes!.trim(),
      },
      parser: (_) {},
    );

    emit(
      state.copyWith(
        status: BusinessDetailStatus.success,
        message: result.isSuccess
            ? 'Conexion creada.'
            : result.error?.message ?? 'No se pudo crear la conexion.',
      ),
    );
  }
}
