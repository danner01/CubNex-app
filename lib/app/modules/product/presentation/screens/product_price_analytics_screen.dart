import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/cup_equivalente.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';

class ProductPriceAnalyticsScreen extends StatefulWidget {
  const ProductPriceAnalyticsScreen({required this.productId, super.key});

  final String productId;

  @override
  State<ProductPriceAnalyticsScreen> createState() =>
      _ProductPriceAnalyticsScreenState();
}

class _ProductPriceAnalyticsScreenState
    extends State<ProductPriceAnalyticsScreen> {
  late Future<_AnalyticsData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData?> _load() async {
    final api = sl<ApiClient>();
    final historyResult = await api.get<Map<String, dynamic>?>(
      '/productos/${widget.productId}/estadisticas-precio',
      parser: (json) => json is Map
          ? Map<String, dynamic>.from(json)
          : null,
    );
    final similaresResult = await api.get<Map<String, dynamic>?>(
      '/productos/${widget.productId}/similares',
      parser: (json) => json is Map
          ? Map<String, dynamic>.from(json)
          : null,
    );
    if (!historyResult.isSuccess || historyResult.data == null) {
      return null;
    }
    return _AnalyticsData.fromJson(
      historyResult.data!,
      similarList: similaresResult.data?['similares'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evolucion de precio')),
      body: FutureBuilder<_AnalyticsData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return _ErrorView(
              onRetry: () => setState(() => _future = _load()),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                data.nombre,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Historico en ${data.monedaActual} por dia capturado.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ResumenStats(data: data),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variacion del precio',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 14),
                      if (data.serie.length < 2)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              'Aun no hay suficiente historico. Vuelve en un par de dias.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: LineChart(
                            _chartData(data),
                            duration: const Duration(milliseconds: 250),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Comparado con otros negocios',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              if (data.similares.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No encontramos productos similares en la plataforma todavia.',
                    ),
                  ),
                )
              else
                ...data.similares.map(
                  (similar) => _SimilarTile(
                    similar: similar,
                    onTap: () => _openProduct(context, similar.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  LineChartData _chartData(_AnalyticsData data) {
    final spots = <FlSpot>[];
    for (var index = 0; index < data.serie.length; index++) {
      final punto = data.serie[index];
      spots.add(FlSpot(index.toDouble(), punto.precio));
    }
    final valores = spots.map((spot) => spot.y).toList();
    final minY = valores.reduce((a, b) => a < b ? a : b);
    final maxY = valores.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY).abs() * 0.12;
    final yMin = (minY - padding).toDouble();
    final yMax = (maxY + padding).toDouble();

    return LineChartData(
      minX: 0,
      maxX: (spots.length - 1).toDouble(),
      minY: yMin <= 0 ? yMin : 0,
      maxY: yMax,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.serie.length) {
                return const SizedBox.shrink();
              }
              final show = index == 0 ||
                  index == data.serie.length - 1 ||
                  index % (data.serie.length ~/ 5 + 1) == 0;
              if (!show) return const SizedBox.shrink();
              return Text(
                data.serie[index].fechaLabel,
                style: Theme.of(context).textTheme.labelSmall,
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: false,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.secondary,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.12),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              final label = index >= 0 && index < data.serie.length
                  ? data.serie[index].fechaLabel
                  : '';
              return LineTooltipItem(
                '$label\n${spot.y.toStringAsFixed(0)} ${data.monedaActual}',
                const TextStyle(fontWeight: FontWeight.w800),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  void _openProduct(BuildContext context, String productId) {
    context.go(AppRoutes.productDetail.replaceAll(':id', productId));
  }
}

class _ResumenStats extends StatelessWidget {
  const _ResumenStats({required this.data});

  final _AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final resumen = data.resumen;
    final minimo = resumen.minimo;
    final maximo = resumen.maximo;
    final promedio = resumen.promedio;
    final ultimo = resumen.ultimo;
    final variacion = resumen.variacionPorcentual;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(
              label: 'Minimo',
              value: minimo == null ? '-' : '${_fmt(minimo)} ${data.monedaActual}',
            ),
            _StatChip(
              label: 'Maximo',
              value: maximo == null ? '-' : '${_fmt(maximo)} ${data.monedaActual}',
            ),
            _StatChip(
              label: 'Promedio',
              value: promedio == null ? '-' : '${_fmt(promedio)} ${data.monedaActual}',
            ),
            _StatChip(
              label: 'Ultimo',
              value: ultimo == null ? '-' : '${_fmt(ultimo)} ${data.monedaActual}',
            ),
            if (variacion != null)
              _StatChip(
                label: 'Variacion',
                value: '${variacion >= 0 ? '+' : ''}${variacion.toStringAsFixed(1)}%',
                highlight: variacion < 0 ? Colors.green : Colors.red,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.highlight});

  final String label;
  final String value;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: highlight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarTile extends StatelessWidget {
  const _SimilarTile({required this.similar, required this.onTap});

  final _SimilarProduct similar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          similar.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (similar.marca?.isNotEmpty == true)
              Text(similar.marca!),
            CupEquivalente(precio: similar.precio, moneda: similar.moneda),
          ],
        ),
        trailing: Text(
          similar.precio == null
              ? 'Consultar'
              : '${_fmt(similar.precio!)} ${similar.moneda ?? 'CUP'}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No pudimos cargar la evolucion de precio.'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Resumen {
  const _Resumen({
    this.minimo,
    this.maximo,
    this.promedio,
    this.primero,
    this.ultimo,
    this.variacionPorcentual,
  });

  final double? minimo;
  final double? maximo;
  final double? promedio;
  final double? primero;
  final double? ultimo;
  final double? variacionPorcentual;

  factory _Resumen.fromJson(dynamic json) {
    if (json is! Map) return const _Resumen();
    return _Resumen(
      minimo: _num(json['minimo']),
      maximo: _num(json['maximo']),
      promedio: _num(json['promedio']),
      primero: _num(json['primero']),
      ultimo: _num(json['ultimo']),
      variacionPorcentual: _num(json['variacion_porcentual']),
    );
  }
}

class _SeriePunto {
  const _SeriePunto({required this.fecha, required this.precio});

  final String fecha;
  final double precio;

  String get fechaLabel {
    final parsed = DateTime.tryParse(fecha);
    if (parsed == null) return fecha;
    return '${parsed.day}/${parsed.month}';
  }
}

class _SimilarProduct {
  const _SimilarProduct({
    required this.id,
    required this.nombre,
    this.marca,
    this.precio,
    this.moneda,
  });

  final String id;
  final String nombre;
  final String? marca;
  final double? precio;
  final String? moneda;

  factory _SimilarProduct.fromJson(Map<String, dynamic> json) {
    return _SimilarProduct(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      marca: json['marca']?.toString(),
      precio: _num(json['precio']),
      moneda: json['moneda']?.toString(),
    );
  }
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.nombre,
    required this.monedaActual,
    required this.resumen,
    required this.serie,
    required this.similares,
  });

  final String nombre;
  final String monedaActual;
  final _Resumen resumen;
  final List<_SeriePunto> serie;
  final List<_SimilarProduct> similares;

  factory _AnalyticsData.fromJson(
    Map<String, dynamic> json, {
    dynamic similarList,
  }) {
    final rawSerie = json['serie'];
    final serie = <_SeriePunto>[];
    if (rawSerie is List) {
      for (final item in rawSerie) {
        if (item is! Map) continue;
        final precio = _num(item['precio']);
        if (precio == null) continue;
        serie.add(
          _SeriePunto(
            fecha: item['fecha']?.toString() ?? '',
            precio: precio,
          ),
        );
      }
    }
    serie.sort((a, b) => a.fecha.compareTo(b.fecha));

    final similares = <_SimilarProduct>[];
    if (similarList is List) {
      for (final item in similarList) {
        if (item is! Map) continue;
        similares.add(_SimilarProduct.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    return _AnalyticsData(
      nombre: json['nombre']?.toString() ?? '',
      monedaActual: json['moneda_actual']?.toString() ?? 'CUP',
      resumen: _Resumen.fromJson(json['resumen']),
      serie: serie,
      similares: similares,
    );
  }
}

double? _num(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}

String _fmt(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  if (rounded == rounded.roundToDouble()) {
    return '${rounded.toInt()}';
  }
  return '$rounded'.replaceAll('.', ',');
}