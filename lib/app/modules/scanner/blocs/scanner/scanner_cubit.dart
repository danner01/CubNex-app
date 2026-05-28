import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/http/api_client.dart';
import '../../../home/data/models/product_model.dart';
import 'scanner_state.dart';

class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const ScannerState());

  final ApiClient _apiClient;
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
          message: 'Codigo reconocido.',
        ),
      );
      _processing = false;
      return;
    }

    final result = await _apiClient.post<List<ProductModel>>(
      '/productos/buscar-codigo',
      data: {'codigo_barras': code},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        if (json is Map) {
          final products = json['productos'] ?? json['datos'] ?? json['items'];
          if (products is List) {
            return products
                .whereType<Map>()
                .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
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
          message: result.error?.message ?? 'No se pudo buscar el codigo.',
        ),
      );
      _processing = false;
      return;
    }

    final products = result.data ?? const [];
    emit(
      state.copyWith(
        status: ScannerStatus.success,
        products: products,
        message: products.isEmpty
            ? 'No encontramos productos con ese codigo.'
            : 'Producto encontrado.',
      ),
    );
    _processing = false;
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
      if (segment == 'store' ||
          segment == 'tienda' ||
          segment == 'negocio') {
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
      data: {
        'tipo': _scanType(code),
        'contenido': code,
      },
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
