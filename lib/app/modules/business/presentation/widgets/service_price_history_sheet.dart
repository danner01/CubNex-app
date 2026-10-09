import 'package:flutter/material.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../product/presentation/widgets/product_price_history_chart.dart';
import '../../data/models/service_price_history.dart';

/// Abre una hoja con el historico de precios (1 anio) de un servicio de
/// cualquiera de los catalogos con trazabilidad: menu_items, transporte,
/// propiedades o combustibles.
Future<void> showServicePriceHistorySheet(
  BuildContext context, {
  required String coleccion,
  required String itemId,
  required String nombre,
  String labelSecundaria = 'Compra',
  bool mostrarSecundaria = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => ServicePriceHistorySheet(
      coleccion: coleccion,
      itemId: itemId,
      nombre: nombre,
      labelSecundaria: labelSecundaria,
      mostrarSecundaria: mostrarSecundaria,
    ),
  );
}

class ServicePriceHistorySheet extends StatefulWidget {
  const ServicePriceHistorySheet({
    required this.coleccion,
    required this.itemId,
    required this.nombre,
    this.labelSecundaria = 'Compra',
    this.mostrarSecundaria = true,
    super.key,
  });

  final String coleccion;
  final String itemId;
  final String nombre;
  final String labelSecundaria;
  final bool mostrarSecundaria;

  @override
  State<ServicePriceHistorySheet> createState() =>
      _ServicePriceHistorySheetState();
}

class _ServicePriceHistorySheetState extends State<ServicePriceHistorySheet> {
  late Future<ServicePriceHistory?> _history;

  @override
  void initState() {
    super.initState();
    _history = _load();
  }

  Future<ServicePriceHistory?> _load() async {
    final apiClient = sl<ApiClient>();
    final result = await apiClient.get<ServicePriceHistory?>(
      '/servicios/${widget.coleccion}/${widget.itemId}/precio-historico',
      queryParameters: const {'dias': '365'},
      parser: (json) {
        if (json is! Map) return null;
        return ServicePriceHistory.fromJson(Map<String, dynamic>.from(json));
      },
    );
    if (!result.isSuccess) {
      throw StateError(result.error?.message ?? 'No fue posible cargar.');
    }
    return result.data;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombre,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Historico de precios (1 anio)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<ServicePriceHistory?>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final history = snapshot.data;
                if (history == null || history.serie.isEmpty) {
                  return Text(
                    'Este servicio aun no tiene suficiente historico de precios.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductPriceHistoryChart(
                      serie: history.serie,
                      moneda: history.monedaActual,
                      labelPrimaria: 'Venta',
                      labelSecundaria: widget.labelSecundaria,
                      mostrarSecundaria: widget.mostrarSecundaria,
                    ),
                    const SizedBox(height: 12),
                    _ResumenRow(history: history),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenRow extends StatelessWidget {
  const _ResumenRow({required this.history});

  final ServicePriceHistory history;

  String _fmt(double? value) {
    if (value == null) return '-';
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final resumen = history.resumen;
    return Row(
      children: [
        _ResumenChip(
          label: 'Promedio',
          value: '${_fmt(resumen.promedio)} ${history.monedaActual}',
        ),
        const SizedBox(width: 8),
        _ResumenChip(
          label: 'Min',
          value: '${_fmt(resumen.minimo)} ${history.monedaActual}',
        ),
        const SizedBox(width: 8),
        _ResumenChip(
          label: 'Max',
          value: '${_fmt(resumen.maximo)} ${history.monedaActual}',
        ),
        const SizedBox(width: 8),
        _ResumenChip(
          label: 'Variacion',
          value: resumen.variacionPorcentual == null
              ? '-'
              : '${resumen.variacionPorcentual!.toStringAsFixed(1)}%',
        ),
      ],
    );
  }
}

class _ResumenChip extends StatelessWidget {
  const _ResumenChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}