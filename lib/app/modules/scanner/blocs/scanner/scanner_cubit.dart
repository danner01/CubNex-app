import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/product_model.dart';
import 'scanner_state.dart';

class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const ScannerState());

  final ApiClient _apiClient;
  final ImagePicker _picker = ImagePicker();
  bool _processing = false;

  Future<void> processCode(String rawValue) async {
    final code = rawValue.trim();
    if (code.isEmpty || _processing) return;

    _processing = true;
    emit(
      state.copyWith(
        status: ScannerStatus.resolving,
        code: code,
        products: const [],
      ),
    );
    await _saveScan(code);

    final directTarget = resolveDirectTarget(code);
    if (directTarget != null) {
      emit(
        state.copyWith(
          status: ScannerStatus.success,
          message: 'Enlace reconocido.',
        ),
      );
      _processing = false;
      return;
    }

    emit(
      state.copyWith(
        status: ScannerStatus.failure,
        message:
            'Para buscar productos usa una foto del producto o etiqueta. Los codigos solo abren enlaces directos.',
      ),
    );
    _processing = false;
  }

  Future<void> pickAndSearchProduct(ImageSource source) async {
    if (_processing) return;

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 72,
      maxWidth: 1280,
    );
    if (image == null) return;

    _processing = true;
    emit(
      state.copyWith(
        status: ScannerStatus.resolving,
        code: 'Imagen de producto',
        products: const [],
      ),
    );

    try {
      final bytes = await image.readAsBytes();
      final imageBase64 = base64Encode(bytes);
      await _saveVisualScan(image.name);
      await _searchVisual(
        {
          'imagen_base64': imageBase64,
          'tipo_deteccion': 'producto_visual',
          'guardar_historial': true,
          'limite': 30,
          'min_score': 10,
        },
        emptyMessage:
            'No encontramos productos parecidos. Prueba con una foto mas clara de la etiqueta o empaque.',
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ScannerStatus.failure,
          message: 'No se pudo analizar la imagen. Intenta de nuevo.',
        ),
      );
    } finally {
      _processing = false;
    }
  }

  Future<void> searchByDetectedText(String text) async {
    final query = text.trim();
    if (query.isEmpty || _processing) return;

    _processing = true;
    emit(
      state.copyWith(
        status: ScannerStatus.resolving,
        code: query,
        products: const [],
      ),
    );
    await _saveVisualScan(query);
    await _searchVisual({
      'texto_detectado': query,
      'limite': 30,
      'min_score': 6,
    }, emptyMessage: 'No encontramos productos parecidos a ese texto.');
    _processing = false;
  }

  Future<void> _searchVisual(
    Map<String, dynamic> payload, {
    required String emptyMessage,
  }) async {
    final result = await _apiClient.post<List<ProductModel>>(
      '/productos/buscar-visual',
      data: payload,
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
        if (json is Map) {
          final products = json['productos'] ?? json['datos'] ?? json['items'];
          if (products is List) {
            return products
                .whereType<Map>()
                .map(
                  (item) =>
                      ProductModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
          }
        }
        return const [];
      },
    );

    if (!result.isSuccess) {
      emit(
        state.copyWith(
          status: ScannerStatus.failure,
          message: result.error?.message ?? 'No se pudo analizar el producto.',
        ),
      );
      return;
    }

    final products = result.data ?? const [];
    emit(
      state.copyWith(
        status: ScannerStatus.success,
        products: products,
        message: products.isEmpty
            ? emptyMessage
            : products.length == 1
            ? 'Producto parecido encontrado.'
            : 'Encontramos ${products.length} productos parecidos.',
      ),
    );
  }

  String? resolveDirectTarget(String code) {
    final uri = Uri.tryParse(code);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index].toLowerCase();
      final next = index + 1 < segments.length ? segments[index + 1] : null;
      if (next == null || next.isEmpty) continue;
      if (segment == 'product' || segment == 'producto') {
        return '/product/$next';
      }
      if (segment == 'store' || segment == 'tienda' || segment == 'negocio') {
        return '/store/$next';
      }
    }

    if (_uuidRegex.hasMatch(code)) return '/product/$code';
    return null;
  }

  void restart() {
    _processing = false;
    emit(const ScannerState());
  }

  Future<void> _saveScan(String code) async {
    await _apiClient.post<void>(
      '/historial/escaneos',
      data: {'tipo': _scanType(code), 'contenido': code},
      parser: (_) {},
    );
  }

  Future<void> _saveVisualScan(String content) async {
    await _apiClient.post<void>(
      '/historial/escaneos',
      data: {'tipo': 'etiqueta_ia', 'contenido': content},
      parser: (_) {},
    );
  }

  String _scanType(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('qr') || lower.startsWith('http')) return 'qr_producto';
    return 'codigo_barras';
  }

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}
