import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../../home/data/models/product_model.dart';
import '../../data/models/cart_item_model.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit({required ApiClient apiClient, required Box<dynamic> cartBox})
    : _apiClient = apiClient,
      _cartBox = cartBox,
      super(const CartState());

  final ApiClient _apiClient;
  final Box<dynamic> _cartBox;
  bool _restored = false;
  static const _deliveryModesKey = '__delivery_modes__';

  void restore() {
    if (_restored) return;
    _restored = true;

    final items = _cartBox.values
        .whereType<Map>()
        .map((item) => CartItemModel.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.product.id.isNotEmpty)
        .toList();
    final deliveryModesRaw = _cartBox.get(_deliveryModesKey);
    final deliveryModes = deliveryModesRaw is Map
        ? deliveryModesRaw.map(
            (key, value) => MapEntry(key.toString(), value == true),
          )
        : <String, bool>{};

    if (items.isNotEmpty) {
      emit(
        state.copyWith(
          items: items,
          deliveryByBusiness: deliveryModes,
          status: CartStatus.initial,
        ),
      );
    }
  }

  void addProduct(ProductModel product) {
    final existingIndex = state.items.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      final next = [...state.items];
      final current = next[existingIndex];
      next[existingIndex] = current.copyWith(quantity: current.quantity + 1);
      emit(state.copyWith(items: next, status: CartStatus.initial));
      _persist(next);
      return;
    }

    final next = [...state.items, CartItemModel(product: product)];
    emit(state.copyWith(items: next, status: CartStatus.initial));
    _persist(next);
  }

  void removeProduct(String productId) {
    final next = state.items
        .where((item) => item.product.id != productId)
        .toList();
    emit(state.copyWith(items: next, status: CartStatus.initial));
    _persist(next);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final next = state.items
        .map(
          (item) => item.product.id == productId
              ? item.copyWith(quantity: quantity)
              : item,
        )
        .toList();
    emit(state.copyWith(items: next, status: CartStatus.initial));
    _persist(next);
  }

  void setDeliveryForBusiness(String businessId, bool requestDelivery) {
    final next = {...state.deliveryByBusiness, businessId: requestDelivery};
    emit(state.copyWith(deliveryByBusiness: next, status: CartStatus.initial));
    _persist(state.items, deliveryByBusiness: next);
  }

  Future<void> submit({
    required String contactName,
    String? phone,
    String? email,
    String? message,
    String? deliveryAddress,
    String? discountCode,
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
      (item) =>
          item.product.businessId == null || item.product.businessId!.isEmpty,
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

    final grouped = <String, List<CartItemModel>>{};
    for (final item in state.items) {
      grouped.putIfAbsent(item.product.businessId!, () => []).add(item);
    }

    for (final entry in grouped.entries) {
      final result = await _createGroupedOrder(
        businessId: entry.key,
        items: entry.value,
        contactName: contactName,
        phone: phone,
        email: email,
        message: message,
        deliveryAddress: deliveryAddress,
        discountCode: discountCode,
        requestDelivery: state.deliveryByBusiness[entry.key] ?? false,
      );

      if (!result.isSuccess) {
        if (_shouldFallbackToLegacyPedidos(result.error?.statusCode)) {
          final fallback = await _submitLegacyPedidos(
            items: entry.value,
            contactName: contactName,
            phone: phone,
            email: email,
            message: message,
            deliveryAddress: deliveryAddress,
            discountCode: discountCode,
            requestDelivery: state.deliveryByBusiness[entry.key] ?? false,
          );
          if (fallback) continue;
        }

        emit(
          state.copyWith(
            status: CartStatus.failure,
            message: result.error?.message ?? 'No se pudo enviar el pedido.',
          ),
        );
        return;
      }
    }

    await clear();
    emit(
      const CartState(
        status: CartStatus.success,
        message: 'Orden enviada al negocio.',
      ),
    );
  }

  Future<void> clear() async {
    await _cartBox.clear();
    emit(const CartState());
  }

  Future<ApiResult<bool>> _createGroupedOrder({
    required String businessId,
    required List<CartItemModel> items,
    required String contactName,
    String? phone,
    String? email,
    String? message,
    String? deliveryAddress,
    String? discountCode,
    required bool requestDelivery,
  }) {
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final currency = items.first.product.currency ?? 'CUP';

    return _apiClient.post<bool>(
      '/ordenes',
      data: {
        'negocio_id': businessId,
        'tipo': requestDelivery ? 'delivery' : 'recogida',
        'estado': requestDelivery ? 'reservado_delivery' : 'reservado_recogida',
        'nombre_contacto': contactName,
        'telefono': phone,
        'email': email,
        'mensaje': message,
        'moneda': currency,
        'total_estimado': total,
        'solicita_delivery': requestDelivery,
        'direccion_entrega': deliveryAddress,
        'origen': 'apk',
        'metadata': {
          if (discountCode?.trim().isNotEmpty == true)
            'codigo_descuento': discountCode!.trim(),
        },
        'items': items
            .map(
              (item) => {
                'producto_id': item.product.id,
                'nombre': item.product.name,
                'marca': item.product.brand,
                'cantidad': item.quantity,
                'precio_unitario': item.product.currentPrice ?? 0,
                'moneda': item.product.currency ?? currency,
                'subtotal': item.subtotal,
                'imagen_url': item.product.imageUrl,
              },
            )
            .toList(),
      },
      parser: (_) => true,
    );
  }

  Future<bool> _submitLegacyPedidos({
    required List<CartItemModel> items,
    required String contactName,
    String? phone,
    String? email,
    String? message,
    String? deliveryAddress,
    String? discountCode,
    required bool requestDelivery,
  }) async {
    for (final item in items) {
      final result = await _apiClient.post<bool>(
        '/pedidos',
        data: {
          'negocio_id': item.product.businessId,
          'producto_id': item.product.id,
          'tipo': 'producto',
          'estado': requestDelivery
              ? 'reservado_delivery'
              : 'reservado_recogida',
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
            'solicita_delivery': requestDelivery,
            'direccion_entrega': deliveryAddress,
            if (discountCode?.trim().isNotEmpty == true)
              'codigo_descuento': discountCode!.trim(),
          },
        },
        parser: (_) => true,
      );
      if (!result.isSuccess) return false;
    }
    return true;
  }

  bool _shouldFallbackToLegacyPedidos(int? statusCode) {
    return statusCode == 404 || statusCode == 501 || statusCode == 400;
  }

  Future<void> _persist(
    List<CartItemModel> items, {
    Map<String, bool>? deliveryByBusiness,
  }) async {
    await _cartBox.clear();
    for (final item in items) {
      await _cartBox.put(item.product.id, item.toJson());
    }
    final modes = deliveryByBusiness ?? state.deliveryByBusiness;
    if (modes.isNotEmpty) {
      await _cartBox.put(_deliveryModesKey, modes);
    }
  }
}
