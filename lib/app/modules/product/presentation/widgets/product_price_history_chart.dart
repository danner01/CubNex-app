import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/models/product_price_history.dart';

/// Grafico de linea del historico de precios de un producto:
/// precio de venta y precio de compra (promedio por dia).
///
/// Tambien se reutiliza para el historico de precios de servicios
/// (menu_items, transporte, propiedades, combustibles): la serie principal
/// llega en [ProductPricePoint.precioVenta] y la serie secundaria
/// (p. ej. precio/km) en [ProductPricePoint.precioCompra], con etiquetas
/// configurables por catalogo.
class ProductPriceHistoryChart extends StatelessWidget {
  const ProductPriceHistoryChart({
    required this.serie,
    this.moneda = 'CUP',
    this.height = 210,
    this.labelPrimaria = 'Venta',
    this.labelSecundaria = 'Compra',
    this.mostrarSecundaria = true,
    super.key,
  });

  final List<ProductPricePoint> serie;
  final String moneda;
  final double height;
  final String labelPrimaria;
  final String labelSecundaria;
  final bool mostrarSecundaria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ventaColor = theme.colorScheme.secondary;
    final compraColor = theme.colorScheme.outline;

    final ventaSpots = <FlSpot>[];
    final compraSpots = <FlSpot>[];
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (var index = 0; index < serie.length; index++) {
      final punto = serie[index];
      final venta = punto.precioVenta;
      final compra = punto.precioCompra;
      if (venta != null) {
        ventaSpots.add(FlSpot(index.toDouble(), venta));
        if (venta < minY) minY = venta;
        if (venta > maxY) maxY = venta;
      }
      if (compra != null) {
        compraSpots.add(FlSpot(index.toDouble(), compra));
        if (compra < minY) minY = compra;
        if (compra > maxY) maxY = compra;
      }
    }

    if (ventaSpots.isEmpty && compraSpots.isEmpty) {
      return const SizedBox.shrink();
    }

    if (minY == double.infinity || maxY == double.negativeInfinity) {
      minY = 0;
      maxY = 1;
    }
    final rango = (maxY - minY).abs();
    final padding = rango == 0 ? maxY * 0.1 : rango * 0.12;
    final yMin = minY - padding;
    final yMax = maxY + padding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendItem(color: ventaColor, label: labelPrimaria),
            if (mostrarSecundaria) ...[
              const SizedBox(width: 14),
              _LegendItem(color: compraColor, label: labelSecundaria),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: serie.length > 1 ? (serie.length - 1).toDouble() : 1,
              minY: yMin,
              maxY: yMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: serie.length < 40,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= serie.length) {
                        return const SizedBox.shrink();
                      }
                      final show = index == 0 ||
                          index == serie.length - 1 ||
                          index % (serie.length ~/ 5 + 1) == 0;
                      if (!show) return const SizedBox.shrink();
                      return Text(
                        serie[index].fechaLabel,
                        style: theme.textTheme.labelSmall,
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: false,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              lineBarsData: [
                if (ventaSpots.isNotEmpty)
                  LineChartBarData(
                    spots: ventaSpots,
                    isCurved: true,
                    color: ventaColor,
                    barWidth: 2.6,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: ventaSpots.length == 1),
                    belowBarData: BarAreaData(
                      show: ventaSpots.length > 1,
                      color: ventaColor.withValues(alpha: 0.10),
                    ),
                  ),
                if (mostrarSecundaria && compraSpots.isNotEmpty)
                  LineChartBarData(
                    spots: compraSpots,
                    isCurved: true,
                    color: compraColor,
                    barWidth: 2.2,
                    dashArray: [6, 4],
                    dotData: FlDotData(show: compraSpots.length == 1),
                  ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.surface,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      final label = index >= 0 && index < serie.length
                          ? serie[index].fechaLabel
                          : '';
                      return LineTooltipItem(
                        '$label\n${spot.y.toStringAsFixed(2)} $moneda',
                        const TextStyle(fontWeight: FontWeight.w800),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}