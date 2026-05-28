import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/product_model.dart';
import '../../data/models/cart_item_model.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const CartState());

  final ApiClient _apiClient;

  void addProduct(ProductModel product) {
    final existingIndex = state.items.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      final next = [...state.items];
      final current = next[existingIndex];
      next[existingIndex] = current.copyWith(quantity: current.quantity + 1);
      emit(state.copyWith(items: next, status: CartStatus.initial));
      return;
    }

    emit(
      state.copyWith(
        items: [...state.items, CartItemModel(product: product)],
        status: CartStatus.initial,
      ),
    );
  }

  void removeProduct(String productId) {
    emit(
      state.copyWith(
        items: state.items
            .where((item) => item.product.id != productId)
            .toList(),
        status: CartStatus.initial,
      ),
    );
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    emit(
      state.copyWith(
        items: state.items
            .map(
              (item) => item.product.id == productId
                  ? item.copyWith(quantity: quantity)
                  : item,
            )
            .toList(),
        status: CartStatus.initial,
      ),
    );
  }

  Future<void> submit({
    required String contactName,
    String? phone,
    String? email,
    String? message,
  }) async {
    if (state.items.isEmpty) {
      emit(
        state.copyWith(
          status: CartStatus.failure,
          message: 'El carrito esta vacio.',
        ),
      );
      return;
    }

    final invalid = state.items.where(
      (item) => item.product.businessId == null || item.product.businessId!.isEmpty,
    );
    if (invalid.isNotEmpty) {
      emit(
        state.copyWith(
          status: CartStatus.failure,
          message: 'Hay productos sin negocio asociado.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: CartStatus.submitting));

    for (final item in state.items) {
      final result = await _apiClient.post<bool>(
        '/pedidos',
        data: {
          'negocio_id': item.product.businessId,
          'producto_id': item.product.id,
          'tipo': 'producto',
          'nombre_contacto': contactName,
          'telefono': phone,
          'email': email,
          'mensaje': message,
          'cantidad': item.quantity,
          'moneda': item.product.currency ?? 'CUP',
          'total_estimado': item.subtotal,
          'origen': 'apk',
          'metadata': {
            'producto_nombre': item.product.name,
            'marca': item.product.brand,
          },
        },
        parser: (_) => true,
      );

      if (!result.isSuccess) {
        emit(
          state.copyWith(
            status: CartStatus.failure,
            message: result.error?.message ?? 'No se pudo enviar el pedido.',
          ),
        );
        return;
      }
    }

    emit(
      const CartState(
        status: CartStatus.success,
        message: 'Solicitud enviada al negocio.',
      ),
    );
  }
}
