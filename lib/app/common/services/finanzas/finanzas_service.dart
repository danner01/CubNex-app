import '../../../config/http/api_client.dart';
import '../tasas/tasas_models.dart';
import '../tasas/tasas_service.dart';
import 'finanzas_models.dart';

class TickerSnapshot {
  const TickerSnapshot({required this.referencia, this.monedas = const []});

  final TasasMercado referencia;
  final List<TickerMoneda> monedas;
}

class FinanzasService {
  FinanzasService({required ApiClient apiClient, required TasasService tasasService})
      : _apiClient = apiClient,
        _tasasService = tasasService;

  final ApiClient _apiClient;
  final TasasService _tasasService;

  static const _ticksRecientes = <String>['USD', 'EUR', 'MLC', 'USDT'];
  static const _ttlCache = Duration(seconds: 60);

  TickerSnapshot? _tickerCache;
  DateTime? _tickerAt;

  Future<FinanzasProductos> obtenerProductos() async {
    final result = await _apiClient.get<FinanzasProductos>(
      '/finanzas/productos',
      parser: (json) {
        if (json is! Map) return FinanzasProductos.vacio;
        return FinanzasProductos.fromJson(Map<String, dynamic>.from(json));
      },
    );
    return result.isSuccess ? result.data ?? FinanzasProductos.vacio : FinanzasProductos.vacio;
  }

  Future<TickerSnapshot> obtenerTicker({bool force = false}) async {
    final cache = _tickerCache;
    final at = _tickerAt;
    if (!force && cache != null && at != null) {
      if (DateTime.now().difference(at) < _ttlCache) return cache;
    }

    final referencia =
        await _tasasService.referenciaCached() ?? await _tasasService.obtenerReferencia();
    if (referencia == null) {
      if (cache != null) return cache;
      return const TickerSnapshot(referencia: TasasMercado(tasas: {}, oficial: {}, fuente: ''));
    }

    final disponibles =
        _ticksRecientes.where((codigo) => referencia.tasas.containsKey(codigo)).toList();

    final historiales = <String, List<TasaHistorialPunto>>{};
    await Future.wait(
      disponibles.map((codigo) async {
        historiales[codigo] = await _tasasService.obtenerHistorial(moneda: codigo, dias: 7);
      }),
    );

    final monedas = <TickerMoneda>[];
    for (final codigo in disponibles) {
      final tasa = referencia.tasas[codigo];
      final valor = tasa?.cup ?? tasa?.venta ?? tasa?.compra;
      monedas.add(
        TickerMoneda(
          codigo: codigo,
          valor: valor,
          tendencia: tendenciaDiaria(historiales[codigo]),
        ),
      );
    }

    final snapshot = TickerSnapshot(referencia: referencia, monedas: monedas);
    _tickerCache = snapshot;
    _tickerAt = DateTime.now();
    return snapshot;
  }

  void invalidarTicker() {
    _tickerCache = null;
    _tickerAt = null;
    _tasasService.invalidarCache();
  }
}

double? tendenciaDiaria(List<TasaHistorialPunto>? puntos) {
  if (puntos == null || puntos.isEmpty) return null;
  final porDia = <String, double>{};
  for (final punto in puntos) {
    final cup = punto.cup;
    if (cup == null) continue;
    final dia = punto.fecha.length >= 10 ? punto.fecha.substring(0, 10) : punto.fecha;
    if (dia.isEmpty) continue;
    porDia[dia] = cup;
  }
  final dias = porDia.keys.toList()..sort();
  if (dias.length < 2) return null;
  final anterior = porDia[dias[dias.length - 2]];
  final ultimo = porDia[dias[dias.length - 1]];
  if (anterior == null || ultimo == null || anterior <= 0) return null;
  return ((ultimo - anterior) / anterior) * 100;
}