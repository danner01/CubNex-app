import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
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
              .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
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
              .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return const [];
      },
    );

    final businessResult = await businessFuture;
    final productsResult = await productsFuture;
    final reviewsResult = await reviewsFuture;

    if (businessResult.isSuccess && businessResult.data != null) {
      emit(
        state.copyWith(
          status: BusinessDetailStatus.success,
          business: businessResult.data,
          products: productsResult.data ?? const [],
          reviews: reviewsResult.data ?? const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessDetailStatus.failure,
        errorMessage: businessResult.error?.message ?? 'No se pudo cargar la tienda.',
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
          status: BusinessDetailStatus.failure,
          message: result.error?.message ?? 'No se pudo publicar la resena.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessDetailStatus.success,
        message: 'Resena publicada.',
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
}
