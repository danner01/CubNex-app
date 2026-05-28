import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/product_model.dart';
import 'product_detail_state.dart';

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const ProductDetailState());

  final ApiClient _apiClient;

  Future<void> load(String id) async {
    emit(state.copyWith(status: ProductDetailStatus.loading));
    final result = await _apiClient.get<ProductModel?>(
      '/productos/$id',
      parser: (json) {
        if (json is List && json.isNotEmpty) {
          return ProductModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        if (json is Map) {
          return ProductModel.fromJson(Map<String, dynamic>.from(json));
        }
        return null;
      },
    );

    if (result.isSuccess && result.data != null) {
      emit(
        state.copyWith(
          status: ProductDetailStatus.success,
          product: result.data,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ProductDetailStatus.failure,
        errorMessage: result.error?.message ?? 'No se pudo cargar el producto.',
      ),
    );
  }
}
