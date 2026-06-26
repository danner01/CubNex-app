import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../data/models/product_label_detection.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';
import 'business_inventory_state.dart';

class BusinessInventoryCubit extends Cubit<BusinessInventoryState> {
  BusinessInventoryCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const BusinessInventoryState());

  final ApiClient _apiClient;

  Future<void> load({BusinessModel? selectedBusiness}) async {
    emit(state.copyWith(status: BusinessInventoryStatus.loading));
    final business = selectedBusiness ?? await _loadFallbackBusiness();
    if (business == null) {
      emit(
        state.copyWith(
          status: BusinessInventoryStatus.failure,
          message: 'No tienes negocio creado.',
        ),
      );
      return;
    }

    await _loadProductsForBusiness(business);
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

    if (!businessResult.isSuccess || businessResult.data == null) {
      return null;
    }

    return businessResult.data;
  }

  Future<void> _loadProductsForBusiness(BusinessModel business) async {
    final productsResult = await _apiClient.get<List<ProductModel>>(
      '/negocios/${business.id}/productos',
      queryParameters: {'limit': 50, 'order': 'created_at.desc'},
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

    if (!productsResult.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessInventoryStatus.failure,
          business: business,
          message:
              productsResult.error?.message ?? 'No se pudo cargar inventario.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BusinessInventoryStatus.success,
        business: business,
        products: productsResult.data ?? const [],
      ),
    );
  }

  Future<void> createProduct({
    required String name,
    String? brand,
    String? description,
    required double price,
    double? transferPrice,
    double? transferPercent,
    String currency = 'CUP',
    int? stock,
    String? category,
    List<String> imageUrls = const [],
    Map<String, dynamic> detectedFeatures = const {},
    bool inInventory = true,
    bool purchasable = true,
  }) async {
    final business = state.business;
    if (business == null) {
      emit(
        state.copyWith(
          status: BusinessInventoryStatus.failure,
          message: 'Primero debes crear o cargar tu negocio.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: BusinessInventoryStatus.saving));
    final result = await _apiClient.post<List<ProductModel>>(
      '/productos',
      data: {
        'negocio_id': business.id,
        'nombre': name,
        'slug': _slug(name),
        'marca': brand,
        'descripcion': description,
        'precio': price,
        'precio_transferencia': transferPrice,
        'porciento_transferencia': transferPercent,
        'moneda': currency,
        'stock': stock,
        'imagenes': imageUrls.take(3).toList(),
        'caracteristicas': {
          if (category?.trim().isNotEmpty == true)
            'categoria': category!.trim(),
          ...detectedFeatures,
        },
        'en_inventario': inInventory,
        'comprable': purchasable,
        'disponible': purchasable,
      },
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

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessInventoryStatus.failure,
          message: result.error?.message ?? 'No se pudo crear el producto.',
        ),
      );
      return;
    }

    await load(selectedBusiness: business);
    emit(
      state.copyWith(
        status: BusinessInventoryStatus.success,
        message: 'Producto creado.',
      ),
    );
  }

  Future<void> updateProduct({
    required ProductModel product,
    required String name,
    String? brand,
    String? description,
    required double price,
    double? transferPrice,
    double? transferPercent,
    String currency = 'CUP',
    int? stock,
    String? category,
    List<String> imageUrls = const [],
    Map<String, dynamic> detectedFeatures = const {},
    bool inInventory = true,
    bool purchasable = true,
  }) async {
    emit(state.copyWith(status: BusinessInventoryStatus.saving));
    final result = await _apiClient.put<List<ProductModel>>(
      '/productos/${product.id}',
      data: {
        'nombre': name,
        'marca': brand,
        'descripcion': description,
        'precio': price,
        'precio_transferencia': transferPrice,
        'porciento_transferencia': transferPercent,
        'moneda': currency,
        'stock': stock,
        'imagenes': imageUrls.take(3).toList(),
        'caracteristicas': {
          ...product.features,
          if (category?.trim().isNotEmpty == true)
            'categoria': category!.trim(),
          ...detectedFeatures,
        },
        'en_inventario': inInventory,
        'comprable': purchasable,
        'disponible': purchasable,
      },
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

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessInventoryStatus.failure,
          message: result.error?.message ?? 'No se pudo editar el producto.',
        ),
      );
      return;
    }

    final business = state.business;
    await load(selectedBusiness: business);
    emit(
      state.copyWith(
        status: BusinessInventoryStatus.success,
        message: 'Producto actualizado.',
      ),
    );
  }

  Future<void> deleteProduct(ProductModel product) async {
    emit(state.copyWith(status: BusinessInventoryStatus.saving));
    final result = await _apiClient.delete<dynamic>('/productos/${product.id}');
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessInventoryStatus.failure,
          message: result.error?.message ?? 'No se pudo eliminar el producto.',
        ),
      );
      return;
    }

    final business = state.business;
    await load(selectedBusiness: business);
    emit(
      state.copyWith(
        status: BusinessInventoryStatus.success,
        message: 'Producto eliminado.',
      ),
    );
  }

  Future<ProductLabelDetection?> detectLabel(String imageBase64) async {
    return detectProductImages(frontImageBase64: imageBase64);
  }

  Future<ProductLabelDetection?> detectProductImages({
    String? frontImageBase64,
    String? backImageBase64,
    bool saveImages = true,
  }) async {
    emit(state.copyWith(status: BusinessInventoryStatus.saving));
    final business = state.business;
    final result = await _apiClient.post<ProductLabelDetection>(
      '/vision-ia/detectar-etiqueta',
      data: {
        if (frontImageBase64 != null) 'imagen_frente_base64': frontImageBase64,
        if (backImageBase64 != null) 'imagen_reverso_base64': backImageBase64,
        if (business != null) 'negocio_id': business.id,
        'guardar_imagenes': saveImages,
        'tipo_deteccion': 'ambos',
      },
      parser: (json) {
        if (json is Map) {
          return ProductLabelDetection.fromJson(
            Map<String, dynamic>.from(json),
          );
        }
        return const ProductLabelDetection();
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: BusinessInventoryStatus.failure,
          message: result.error?.message ?? 'No se pudo analizar la imagen.',
        ),
      );
      return null;
    }

    emit(
      state.copyWith(
        status: BusinessInventoryStatus.success,
        message: 'Datos detectados. Revisa antes de guardar.',
      ),
    );
    return result.data;
  }

  String _slug(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return normalized.isEmpty
        ? 'producto-${DateTime.now().millisecondsSinceEpoch}'
        : '$normalized-${DateTime.now().millisecondsSinceEpoch}';
  }
}
