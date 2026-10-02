import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../common/services/finanzas/finanzas_formatos.dart';
import '../../../../common/services/tasas/tasas_models.dart';
import '../../../../common/services/tasas/tasas_service.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';

import '../widgets/candlestick_chart.dart';

const _subida = Color(0xFF2ECC71);
const _bajada = Color(0xFFE74C3C);

class FinanzasDetalleScreen extends StatefulWidget {
  const FinanzasDetalleScreen({
    super.key,
    required this.tipo,
    required this.referencia,
    required this.nombre,
  });

  final String tipo;
  final String referencia;
  final String nombre;

  @override
  State<FinanzasDetalleScreen> createState() => _FinanzasDetalleScreenState();
}

class _FinanzasDetalleScreenState extends State<FinanzasDetalleScreen> {
  static const _timeframes = <String>['1D', '7D', '1M', '3M', '1A'];
  static const _diasPorTimeframe = <String, int>{
    '1D': 1,
    '7D': 7,
    '1M': 30,
    '3M': 90,
    '1A': 365,
  };

  final TasasService _tasas = sl<TasasService>();
  final ApiClient _apiClient = sl<ApiClient>();
  String _timeframe = '7D';
  bool _cargando = true;
  String? _error;
  List<Candle> _velas = const [];
  double? _precioActual;

  bool get _esMoneda => widget.tipo == 'moneda';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_esMoneda) {
        final dias = _diasPorTimeframe[_timeframe] ?? 7;
        final puntos = await _tasas.obtenerHistorial(
          moneda: widget.referencia,
          dias: dias,
        );
        if (!mounted) return;
        final velas = _velasDeTasas(puntos, horario: _timeframe == '1D');
        setState(() {
          _velas = velas;
          _precioActual = velas.isEmpty ? null : velas.last.close;
          _cargando = false;
        });
        return;
      }

      final result = await _apiClient.get<Map<String, dynamic>>(
        '/productos/${widget.referencia}/estadisticas-precio',
        parser: (json) => json is Map ? Map<String, dynamic>.from(json) : const {},
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        setState(() {
          _cargando = false;
          _error = 'No se pudieron cargar los precios del producto.';
        });
        return;
      }
      final datos = result.data ?? const {};
      final serie = _serieProducto(datos['serie']);
      final resumen = datos['resumen'];
      final ultimo = resumen is Map ? _num(resumen['ultimo']) : serie.isNotEmpty ? serie.last.$2 : null;
      final dias = _diasPorTimeframe[_timeframe] ?? 365;
      final filtro = DateTime.now().subtract(Duration(days: dias));
      var serieFiltrada = serie
          .where((punto) => !punto.$1.isBefore(filtro))
          .toList();
      if (serieFiltrada.length < 2) serieFiltrada = serie;
      final velas = _velasDePares(serieFiltrada);
      setState(() {
        _velas = velas;
        _precioActual = ultimo;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los datos.';
      });
    }
  }

  List<(DateTime, double)> _serieProducto(Object? raw) {
    if (raw is! List) return const [];
    final lista = <(DateTime, double)>[];
    for (final punto in raw) {
      if (punto is! Map) continue;
      final precio = _num(punto['precio_cup'] ?? punto['precio']);
      final fecha = DateTime.tryParse(punto['fecha']?.toString() ?? '');
      if (precio == null || fecha == null) continue;
      lista.add((fecha, precio));
    }
    lista.sort((a, b) => a.$1.compareTo(b.$1));
    return lista;
  }

  List<Candle> _velasDeTasas(List<TasaHistorialPunto> puntos, {required bool horario}) {
    final pares = <(DateTime, double)>[];
    for (final punto in puntos) {
      final fecha = DateTime.tryParse(punto.fecha);
      final cup = punto.cup;
      if (fecha == null || cup == null) continue;
      pares.add((fecha, cup));
    }
    pares.sort((a, b) => a.$1.compareTo(b.$1));
    return _velasDePares(pares, horario: horario);
  }

  List<Candle> _velasDePares(List<(DateTime, double)> pares, {bool horario = false}) {
    final porClave = <DateTime, List<double>>{};
    for (final par in pares) {
      final t = par.$1;
      final clave = horario
          ? DateTime(t.year, t.month, t.day, t.hour)
          : DateTime(t.year, t.month, t.day);
      porClave.putIfAbsent(clave, () => []).add(par.$2);
    }
    final claves = porClave.keys.toList()..sort();
    final candidatas = <Candle>[];
    for (final clave in claves) {
      final valores = porClave[clave]!;
      candidatas.add(
        Candle(
          tiempo: clave,
          open: valores.first,
          high: valores.reduce(math.max),
          low: valores.reduce(math.min),
          close: valores.last,
        ),
      );
    }
    if (candidatas.length <= 140) return candidatas;
    final step = (candidatas.length / 100).ceil();
    final muestreadas = <Candle>[];
    for (var i = 0; i < candidatas.length; i += step) {
      muestreadas.add(candidatas[i]);
    }
    return muestreadas;
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _velas.isEmpty ? null : _velas.last;
    final tendencia =
        ultima == null ? null : _variacion(ultima.open, ultima.close);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nombre,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _esMoneda
                        ? 'Mercado informal · valores en CUP'
                        : 'Precio promedio en CUP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            _indicadorTendencia(tendencia),
          ],
        ),
        const SizedBox(height: 14),
        _precioPrincipal(tendencia),
        const SizedBox(height: 18),
        _selectorTimeframe(),
        const SizedBox(height: 16),
        if (_cargando)
          const SizedBox(
            height: 240,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (_error != null)
          _mensajeError(context)
        else if (_velas.isEmpty)
          const _AvisoDetalle(texto: 'Sin datos suficientes para este periodo.')
        else
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: CandlestickChart(candelas: _velas),
            ),
          ),
        const SizedBox(height: 14),
        if (!_cargando && _error == null && ultima != null)
          _ResumenVela(candela: ultima),
      ],
    );
  }

  Widget _indicadorTendencia(double? tendencia) {
    if (tendencia == null) {
      return const Icon(Icons.remove_rounded, size: 22, color: Colors.grey);
    }
    final alza = tendencia >= 0;
    final color = alza ? _subida : _bajada;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          alza ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          formatearTendencia(tendencia),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _precioPrincipal(double? tendencia) {
    final alza = tendencia == null || tendencia >= 0;
    final color = tendencia == null ? null : (alza ? _subida : _bajada);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _precioActual == null
              ? '-'
              : '${formatoDinero(_precioActual)} CUP',
          style: TextStyle(
            fontSize: 38,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _esMoneda
              ? 'Precio de referencia del dia'
              : 'Ultimo precio registrado',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _selectorTimeframe() {
    return Row(
      children: [
        for (final tf in _timeframes)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tf),
              selected: tf == _timeframe,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: tf == _timeframe
                    ? Colors.black
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: const Color(0xFFD4AF37),
              onSelected: (_) {
                if (tf == _timeframe) return;
                setState(() => _timeframe = tf);
                _cargar();
              },
            ),
          ),
      ],
    );
  }

  Widget _mensajeError(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_error ?? 'Error')),
          ],
        ),
      ),
    );
  }
}

class _ResumenVela extends StatelessWidget {
  const _ResumenVela({required this.candela});

  final Candle candela;

  @override
  Widget build(BuildContext context) {
    final variacion = _variacion(candela.open, candela.close);
    final alza = variacion >= 0;
    final color = alza ? _subida : _bajada;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ultima vela',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _CeldaVela('Apertura', candela.open),
                _CeldaVela('Cierre', candela.close),
                _CeldaVela('Maximo', candela.high),
                _CeldaVela('Minimo', candela.low),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: _subida,
                ),
                const SizedBox(width: 6),
                Text.rich(
                  TextSpan(
                    text: 'Variacion ${formatearTendencia(variacion)} ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    children: [
                      TextSpan(
                        text: alza ? '(al alza)' : '(a la baja)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CeldaVela extends StatelessWidget {
  const _CeldaVela(this.etiqueta, this.valor);

  final String etiqueta;
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            formatoDinero(valor),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoDetalle extends StatelessWidget {
  const _AvisoDetalle({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }
}

double _variacion(double primero, double ultimo) {
  if (primero <= 0) return 0;
  return ((ultimo - primero) / primero) * 100;
}

double? _num(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}