import '../../../config/http/api_client.dart';
import 'tasas_models.dart';

class TasasService {
  TasasService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<TasasMercado?> obtenerReferencia() async {
    final result = await _apiClient.get<TasasMercado?>(
      '/tasas/referencia',
      parser: _parseMercado,
    );
    return result.isSuccess ? result.data : null;
  }

  Future<List<TasaHistorialPunto>> obtenerHistorial({
    String moneda = 'USD',
    String fuente = 'eltoque',
    int dias = 7,
  }) async {
    final result = await _apiClient.get<List<TasaHistorialPunto>>(
      '/tasas/historial',
      queryParameters: {'moneda': moneda, 'fuente': fuente, 'dias': dias},
      parser: (json) {
        if (json is! Map) return <TasaHistorialPunto>[];
        final raw = json['puntos'];
        if (raw is! List) return <TasaHistorialPunto>[];
        return raw
            .map((item) => TasaHistorialPunto.fromJson(
                  item is Map ? Map<String, dynamic>.from(item) : const {},
                ))
            .toList();
      },
    );
    return result.isSuccess ? result.data ?? [] : [];
  }

  TasasMercado? _parseMercado(dynamic json) {
    if (json is! Map) return null;
    final rawTasas = json['tasas'];
    final tasas = <String, TasaReferencia>{};
    if (rawTasas is Map) {
      for (final entry in rawTasas.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final tasa = TasaReferencia.fromJson(
          Map<String, dynamic>.from(value),
        );
        tasas[entry.key.toString()] = tasa;
      }
    }

    final oficial = <String, TasaValor>{};
    final rawOficial = json['oficial'];
    if (rawOficial is Map) {
      for (final entry in rawOficial.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        oficial[entry.key.toString()] = TasaValor.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    }

    return TasasMercado(
      tasas: tasas,
      oficial: oficial,
      fuente: json['fuente']?.toString() ?? '',
      actualizadoEn: json['actualizado_en']?.toString(),
      fecha: json['fecha']?.toString(),
    );
  }
}