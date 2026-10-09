import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../home/data/models/product_model.dart';
import '../../../product/data/models/product_price_history.dart';
import '../../../product/presentation/widgets/product_price_history_chart.dart';
import '../../blocs/inventory/business_inventory_cubit.dart';
import '../../blocs/inventory/business_inventory_state.dart';
import '../../data/models/business_product_cost.dart';
import '../../data/services/local_product_ocr_service.dart';
import '../widgets/business_switcher.dart';

class BusinessInventoryScreen extends StatelessWidget {
  const BusinessInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessInventoryCubit>()
        ..load(
          selectedBusiness: context
              .read<ActiveBusinessCubit>()
              .state
              .activeBusiness,
        ),
      child: const _BusinessInventoryView(),
    );
  }
}

class _BusinessInventoryView extends StatelessWidget {
  const _BusinessInventoryView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BusinessInventoryCubit, BusinessInventoryState>(
      listener: (context, state) {
        if (state.message != null &&
            (state.status == BusinessInventoryStatus.failure ||
                state.status == BusinessInventoryStatus.success)) {
          showSnackOrAuthDialog(context, state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state.business == null
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider.value(
                      value: context.read<BusinessInventoryCubit>(),
                      child: const _ProductFormSheet(),
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Producto'),
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<BusinessInventoryCubit>().load(
              selectedBusiness: context
                  .read<ActiveBusinessCubit>()
                  .state
                  .activeBusiness,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  'Inventario',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.business == null
                      ? 'Carga o crea tu negocio para administrar productos.'
                      : 'Negocio: ${state.business!.name}',
                ),
                const SizedBox(height: 10),
                BusinessSwitcher(
                  onChanged: () => context.read<BusinessInventoryCubit>().load(
                    selectedBusiness: context
                        .read<ActiveBusinessCubit>()
                        .state
                        .activeBusiness,
                  ),
                ),
                const SizedBox(height: 18),
                if (state.status == BusinessInventoryStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.business == null)
                  const _EmptyInventory(
                    icon: Icons.storefront_outlined,
                    message: 'No encontramos un negocio asociado a tu usuario.',
                  )
                else if (state.products.isEmpty)
                  const _EmptyInventory(
                    icon: Icons.inventory_2_outlined,
                    message: 'Todavia no hay productos cargados.',
                  )
                else
                  ...state.products.map(
                    (product) => _InventoryProductCard(
                      product: product,
                      costo: state.costos[product.id],
                    ),
                  ),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: state.isLoadingMore
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: TextButton.icon(
                              onPressed: () => context
                                  .read<BusinessInventoryCubit>()
                                  .loadMore(),
                              icon: const Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                              ),
                              label: const Text('Cargar mas productos'),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({required this.product, this.costo});

  final ProductModel product;
  final BusinessProductCost? costo;

  @override
  Widget build(BuildContext context) {
    final category = product.features['categoria']?.toString();
    final image = product.imageUrl;
    final visible = product.canBuy;
    final margen = costo?.margenPct;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<BusinessInventoryCubit>(),
            child: _ProductFormSheet(product: product),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 172),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 132,
                  child: image == null
                      ? ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'profitability',
                                  child: Text('Rentabilidad'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => BlocProvider.value(
                                      value: context
                                          .read<BusinessInventoryCubit>(),
                                      child: _ProductFormSheet(
                                        product: product,
                                        costo: costo,
                                      ),
                                    ),
                                  );
                                }
                                if (value == 'profitability') {
                                  _openProfitability(context);
                                }
                                if (value == 'delete') {
                                  _confirmDelete(context);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            product.brand,
                            category,
                          ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if ((product.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            product.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniStatusChip(
                              icon: Icons.inventory_outlined,
                              label: 'Stock ${product.stock ?? 0}',
                            ),
                            _MiniStatusChip(
                              icon: visible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              label: visible ? 'Visible' : 'Oculto',
                              active: visible,
                            ),
                            if (!product.inInventory)
                              const _MiniStatusChip(
                                icon: Icons.remove_shopping_cart_outlined,
                                label: 'Fuera de inventario',
                                active: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.currentPrice == null
                              ? 'Precio a consultar'
                              : '${product.currentPrice!.toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (product.calculatedTransferPrice != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Transferencia: ${product.calculatedTransferPrice!.toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (costo != null && costo!.tieneCosto)
                              _MiniStatusChip(
                                icon: Icons.payments_outlined,
                                label:
                                    'Costo ${costo!.costo?.toStringAsFixed(0) ?? '0'} ${costo!.costoMoneda ?? 'CUP'}',
                              )
                            else
                              const _MiniStatusChip(
                                icon: Icons.payments_outlined,
                                label: 'Sin costo',
                                active: false,
                              ),
                            if (margen != null)
                              _MiniStatusChip(
                                icon: Icons.trending_up_outlined,
                                label: 'Margen ${margen.toStringAsFixed(1)}%',
                                active: margen > 0,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openProfitability(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BusinessInventoryCubit>(),
        child: _ProfitabilitySheet(product: product),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('Vas a eliminar "${product.name}" del inventario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      context.read<BusinessInventoryCubit>().deleteProduct(product);
    }
  }
}

class _ProfitabilitySheet extends StatefulWidget {
  const _ProfitabilitySheet({required this.product});

  final ProductModel product;

  @override
  State<_ProfitabilitySheet> createState() => _ProfitabilitySheetState();
}

class _ProfitabilitySheetState extends State<_ProfitabilitySheet> {
  BusinessProductProfitability? _data;
  ProductPriceHistory? _priceHistory;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cubit = context.read<BusinessInventoryCubit>();
    final results = await Future.wait<Object?>([
      cubit.loadRentabilidad(widget.product.id),
      cubit.loadPriceHistory(widget.product.id),
    ]);
    if (!mounted) return;
    setState(() {
      _data = results[0] as BusinessProductProfitability?;
      _priceHistory = results[1] as ProductPriceHistory?;
      _loading = false;
      _error =
          _data == null ? 'No se pudo cargar la rentabilidad.' : null;
    });
  }

  String _fmt(double? value, {int decimals = 1}) {
    if (value == null) return '--';
    return value.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              const Icon(Icons.trending_up_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_outlined),
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _data == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center),
                ],
              ),
            )
          else if (_data != null)
            ..._buildContent(context),
        ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final data = _data!;
    final theme = Theme.of(context);
    final nominalOffset = data.margenNominalActualPct ?? 0.0;
    final indexadoOffset = data.margenActualPct ?? 0.0;

    return [
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _StatChip(
            label: 'Precio',
            value: '${_fmt(data.precioCup, decimals: 0)} CUP',
            icon: Icons.sell_outlined,
          ),
          _StatChip(
            label: 'Costo',
            value: data.tieneCosto
                ? '${_fmt(data.costo, decimals: 0)} ${data.costoMoneda ?? 'CUP'}'
                : 'Sin costo',
            icon: Icons.payments_outlined,
            active: data.tieneCosto,
          ),
          _StatChip(
            label: 'Margen actual',
            value: '${_fmt(indexadoOffset)}%',
            icon: indexadoOffset >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            active: indexadoOffset >= 0,
          ),
          _StatChip(
            label: 'Margen nominal',
            value: '${_fmt(nominalOffset)}%',
            icon: Icons.trending_flat,
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (!data.tieneCosto)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Este producto no tiene costo registrado. Editalo para agregarlo.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 8),
      if (data.serie.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              data.tieneCosto
                  ? 'Sin historial suficiente para graficar.'
                  : 'La grafica de margen aparecera al guardar el costo.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        )
      else ...[
        SizedBox(
          height: 200,
          child: _MarginChart(data: data),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _StatChip(
                label: 'Mejor margen',
                value: '${_fmt(data.mejorMargenPct)}%',
                icon: Icons.workspace_premium_outlined,
              ),
            ),
            Expanded(
              child: _StatChip(
                label: 'Peor margen',
                value: '${_fmt(data.peorMargenPct)}%',
                icon: Icons.trending_down_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Nominal usa la tasa de hoy sobre toda la serie; '
          'indexado convierte cada fecha con su propia tasa.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 18),
      Text(
        'Historico de precios (1 año)',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Promedio por dia del precio de venta y de compra.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      if (_priceHistory != null &&
          _priceHistory!.serie.isNotEmpty &&
          (_priceHistory!.tieneVenta || _priceHistory!.tieneCompra)) ...[
        ProductPriceHistoryChart(
          serie: _priceHistory!.serie,
          moneda: _priceHistory!.monedaActual,
        ),
        const SizedBox(height: 12),
        _PriceHistoryResumen(
          resumen: _priceHistory!.resumen,
          moneda: _priceHistory!.monedaActual,
        ),
      ] else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Aun no hay historico. Aparecera al guardar precios y costos del producto.',
            style: theme.textTheme.bodySmall,
          ),
        ),
    ];
  }
}

class _PriceHistoryResumen extends StatelessWidget {
  const _PriceHistoryResumen({required this.resumen, required this.moneda});

  final ProductPriceResumen resumen;
  final String moneda;

  String _fmt(double? value) {
    if (value == null) return '-';
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PriceHistoryChip(
          label: 'Promedio',
          value: '${_fmt(resumen.promedio)} $moneda',
        ),
        const SizedBox(width: 8),
        _PriceHistoryChip(label: 'Min', value: '${_fmt(resumen.minimo)} $moneda'),
        const SizedBox(width: 8),
        _PriceHistoryChip(label: 'Max', value: '${_fmt(resumen.maximo)} $moneda'),
        const SizedBox(width: 8),
        _PriceHistoryChip(
          label: 'Variacion',
          value: resumen.variacionPorcentual == null
              ? '-'
              : '${resumen.variacionPorcentual!.toStringAsFixed(1)}%',
        ),
      ],
    );
  }
}

class _PriceHistoryChip extends StatelessWidget {
  const _PriceHistoryChip({required this.label, required this.value});

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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.active = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarginChart extends StatelessWidget {
  const _MarginChart({required this.data});

  final BusinessProductProfitability data;

  @override
  Widget build(BuildContext context) {
    List<double> serieDe(
      double? Function(BusinessProfitabilityPoint p) selector,
    ) {
      return data.serie
          .map(selector)
          .whereType<double>()
          .toList();
    }

    final indexado = serieDe((p) => p.margenIndexadoPct);
    final nominal = serieDe((p) => p.margenNominalPct);
    final values = [...indexado, ...nominal];

    final indexadoSpots = <FlSpot>[
      for (var i = 0; i < indexado.length; i++)
        FlSpot(i.toDouble(), indexado[i]),
    ];
    final nominalSpots = <FlSpot>[
      for (var i = 0; i < nominal.length; i++)
        FlSpot(i.toDouble(), nominal[i]),
    ];

    double? minY;
    double? maxY;
    for (final v in values) {
      minY = minY == null ? v : (v < minY ? v : minY);
      maxY = maxY == null ? v : (v > maxY ? v : maxY);
    }
    final hasY = minY != null && maxY != null && maxY > minY;
    final yMin = hasY ? (minY - 2).toDouble() : -5.0;
    final yMax = hasY ? (maxY + 2).toDouble() : 15.0;

    final theme = Theme.of(context);
    final green = theme.colorScheme.primary;
    final orange = Colors.orange;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: data.serie.length > 1 ? (data.serie.length - 1).toDouble() : 1,
        minY: yMin,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: data.serie.length < 32,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.serie.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  data.serie[index].fecha.length >= 10
                      ? data.serie[index].fecha.substring(5, 10)
                      : data.serie[index].fecha,
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final label = index >= 0 && index < data.serie.length
                    ? data.serie[index].fecha
                    : '';
                return LineTooltipItem(
                  '$label\n${spot.y.toStringAsFixed(1)}%',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          if (indexadoSpots.isNotEmpty)
            LineChartBarData(
              spots: indexadoSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: green,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: green.withValues(alpha: 0.10),
              ),
            ),
          if (nominalSpots.isNotEmpty)
            LineChartBarData(
              spots: nominalSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: orange,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({
    required this.icon,
    required this.label,
    this.active = true,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({this.product, this.costo});

  final ProductModel? product;
  final BusinessProductCost? costo;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _transferPriceController = TextEditingController();
  final _transferPercentController = TextEditingController();
  final _stockController = TextEditingController();
  final _costController = TextEditingController();
  final _categoryController = TextEditingController();
  final _image1Controller = TextEditingController();
  final _image2Controller = TextEditingController();
  final _image3Controller = TextEditingController();
  String _currency = 'CUP';
  String _costCurrency = 'CUP';
  bool _inInventory = true;
  bool _purchasable = true;
  bool _detecting = false;
  bool _saving = false;
  bool _loadingPriceSuggestions = false;
  XFile? _frontPackageImage;
  XFile? _backPackageImage;
  XFile? _image1File;
  XFile? _image2File;
  XFile? _image3File;
  Map<String, dynamic> _detectedFeatures = const {};
  List<_ProductPriceSuggestion> _priceSuggestions = const [];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;
    _nameController.text = product.name;
    _brandController.text = product.brand ?? '';
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price?.toStringAsFixed(2) ?? '';
    _transferPriceController.text =
        product.transferPrice?.toStringAsFixed(2) ?? '';
    _transferPercentController.text =
        product.transferPercent?.toStringAsFixed(2) ?? '';
    _stockController.text = product.stock?.toString() ?? '';
    _categoryController.text = product.features['categoria']?.toString() ?? '';
    _currency = product.currency ?? 'CUP';
    _inInventory = product.inInventory;
    _purchasable = product.purchasable && product.available;
    final costo = widget.costo;
    if (costo != null && costo.tieneCosto && costo.costo != null) {
      _costController.text = costo.costo!.toStringAsFixed(2);
      _costCurrency = costo.costoMoneda ?? 'CUP';
    }
    if (product.imageUrls.isNotEmpty) {
      _image1Controller.text = product.imageUrls.elementAtOrNull(0) ?? '';
      _image2Controller.text = product.imageUrls.elementAtOrNull(1) ?? '';
      _image3Controller.text = product.imageUrls.elementAtOrNull(2) ?? '';
    } else if (product.imageUrl != null) {
      _image1Controller.text = product.imageUrl!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _transferPriceController.dispose();
    _transferPercentController.dispose();
    _stockController.dispose();
    _costController.dispose();
    _categoryController.dispose();
    _image1Controller.dispose();
    _image2Controller.dispose();
    _image3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Editar producto' : 'Nuevo producto',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PackageScanPanel(
                  frontImage: _frontPackageImage,
                  backImage: _backPackageImage,
                  frontImageUrl: _image1Controller.text.trim().isEmpty
                      ? null
                      : _image1Controller.text.trim(),
                  backImageUrl: _image2Controller.text.trim().isEmpty
                      ? null
                      : _image2Controller.text.trim(),
                  detecting: _detecting,
                  onPickFront: () => _pickPackageImage(front: true),
                  onPickBack: () => _pickPackageImage(front: false),
                  onAnalyze:
                      _frontPackageImage == null && _backPackageImage == null
                      ? null
                      : _detectPackageImages,
                ),
                if (_detecting) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Analizando empaque con IA...'),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Categoria del producto',
                    hintText: 'Ej: Bebidas, alimentos, piezas, servicios',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Precio',
                          suffixIcon: _priceSuggestions.isEmpty
                              ? null
                              : Tooltip(
                                  message: _priceSuggestionTooltip,
                                  triggerMode: TooltipTriggerMode.tap,
                                  child: const Icon(
                                    Icons.tips_and_updates_outlined,
                                  ),
                                ),
                        ),
                        validator: (value) =>
                            double.tryParse(value?.trim() ?? '') == null
                            ? 'Precio invalido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 112,
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: 'Moneda'),
                        items: const [
                          DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                          DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) =>
                            setState(() => _currency = value ?? 'CUP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Costo (privado)',
                          hintText: 'Cuanto te costo comprarlo',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          final parsed = double.tryParse(text);
                          if (parsed == null || parsed < 0) {
                            return 'Costo invalido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 112,
                      child: DropdownButtonFormField<String>(
                        initialValue: _costCurrency,
                        decoration: const InputDecoration(labelText: 'Moneda'),
                        items: const [
                          DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                          DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) =>
                            setState(() => _costCurrency = value ?? 'CUP'),
                      ),
                    ),
                  ],
                ),
                if (_costController.text.trim().isEmpty &&
                    _isEditing &&
                    widget.costo?.tieneCosto == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Dejarlo vacio quita el costo de este producto.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (_loadingPriceSuggestions) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ] else if (_priceSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _PriceSuggestionChips(
                    suggestions: _priceSuggestions,
                    currency: _currency,
                    onUse: (suggestion) {
                      _priceController.text = suggestion.price.toStringAsFixed(
                        2,
                      );
                      if (suggestion.source == 'patrones' &&
                          suggestion.id != null) {
                        _sendPatronFeedback(suggestion.id!, true);
                      }
                      setState(() {});
                    },
                  ),
                ],
                if (context
                        .watch<BusinessInventoryCubit>()
                        .state
                        .business
                        ?.acceptsTransfer ==
                    true) ...[
                  const SizedBox(height: 12),
                  _TransferPricePanel(
                    transferPriceController: _transferPriceController,
                    transferPercentController: _transferPercentController,
                    basePriceController: _priceController,
                    currency: _currency,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _inInventory,
                  onChanged: (value) => setState(() => _inInventory = value),
                  title: const Text('Agregar al inventario'),
                  subtitle: const Text(
                    'Permite controlar stock y reservas para este producto.',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _purchasable,
                  onChanged: (value) => setState(() => _purchasable = value),
                  title: const Text('Visible para clientes'),
                  subtitle: const Text(
                    'Solo aparece en tienda si esta activo, en inventario y con stock.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Imagenes del producto',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _ProductImagePreviewRow(
                  urls: [
                    _image1Controller.text.trim(),
                    _image2Controller.text.trim(),
                    _image3Controller.text.trim(),
                  ],
                  files: [_image1File, _image2File, _image3File],
                  onPick: _pickProductImage,
                ),
                const SizedBox(height: 8),
                Text(
                  'Toca cada cuadro para tomar o cargar una imagen. El plan base permite hasta 3 fotos.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? 'Guardando...'
                        : _isEditing
                        ? 'Guardar cambios'
                        : 'Guardar producto',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final cubit = context.read<BusinessInventoryCubit>();
      final product = widget.product;
      final imageUrls = <String>[];
      final imageSlots = [
        (_image1Controller.text.trim(), _image1File, 'principal'),
        (_image2Controller.text.trim(), _image2File, 'adicional-1'),
        (_image3Controller.text.trim(), _image3File, 'adicional-2'),
      ];
      for (final slot in imageSlots) {
        if (slot.$2 != null) {
          final uploaded = await _uploadProductImage(slot.$2!, slot.$3);
          if (uploaded != null) imageUrls.add(uploaded);
        } else if (slot.$1.isNotEmpty) {
          imageUrls.add(slot.$1);
        }
      }
      if (imageUrls.isEmpty) {
        imageUrls.addAll(await _uploadPackagePhotos());
        if (!mounted) return;
      }
      final brand = _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      if (product == null) {
        await cubit.createProduct(
          name: _nameController.text.trim(),
          brand: brand,
          description: description,
          price: double.parse(_priceController.text.trim()),
          transferPrice: _nullableDouble(_transferPriceController.text),
          transferPercent: _nullableDouble(_transferPercentController.text),
          currency: _currency,
          stock: int.tryParse(_stockController.text.trim()),
          category: _categoryController.text.trim(),
          imageUrls: imageUrls,
          detectedFeatures: _detectedFeatures,
          inInventory: _inInventory,
          purchasable: _purchasable,
        );
        final costValue = _nullableDouble(_costController.text);
        if (costValue != null) {
          final creado = cubit.state.products
              .where(
                (item) =>
                    item.name.trim() == _nameController.text.trim(),
              )
              .toList();
          if (creado.isNotEmpty) {
            await cubit.guardarCosto(
              productoId: creado.first.id,
              costo: costValue,
              moneda: _costCurrency,
            );
          }
        }
      } else {
        await cubit.updateProduct(
          product: product,
          name: _nameController.text.trim(),
          brand: brand,
          description: description,
          price: double.parse(_priceController.text.trim()),
          transferPrice: _nullableDouble(_transferPriceController.text),
          transferPercent: _nullableDouble(_transferPercentController.text),
          currency: _currency,
          stock: int.tryParse(_stockController.text.trim()),
          category: _categoryController.text.trim(),
          imageUrls: imageUrls,
          detectedFeatures: _detectedFeatures,
          inInventory: _inInventory,
          purchasable: _purchasable,
        );
        final costValue = _nullableDouble(_costController.text);
        if (costValue != null) {
          await cubit.guardarCosto(
            productoId: product.id,
            costo: costValue,
            moneda: _costCurrency,
          );
        } else if (widget.costo?.tieneCosto == true) {
          await cubit.quitarCosto(product.id);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _priceSuggestionTooltip {
    if (_priceSuggestions.isEmpty) return 'Sin sugerencias';
    final prices = _priceSuggestions.map((item) => item.price).toList();
    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final avg = prices.reduce((a, b) => a + b) / prices.length;
    return 'Precios similares: promedio ${avg.toStringAsFixed(0)} $_currency, rango ${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)} $_currency.';
  }

  double? _nullableDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<List<String>> _uploadPackagePhotos() async {
    final business = context.read<BusinessInventoryCubit>().state.business;
    final photos = [
      ('frente', _frontPackageImage),
      ('reverso', _backPackageImage),
    ].where((item) => item.$2 != null).toList();
    if (photos.isEmpty) return const [];

    final uploaded = <String>[];
    for (final photo in photos) {
      try {
        final bytes = await photo.$2!.readAsBytes();
        final result = await sl<ApiClient>().post<Map<String, dynamic>>(
          '/storage/subir',
          data: {
            'archivo_base64': base64Encode(bytes),
            'nombre_archivo': 'producto-${photo.$1}.jpg',
            'content_type': 'image/jpeg',
            'bucket': 'productos',
            'scope': 'inventario',
            if (business != null) 'negocio_id': business.id,
          },
          parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
        );
        final url = result.data?['public_url']?.toString();
        if (result.isSuccess && url != null && url.isNotEmpty) {
          uploaded.add(url);
        }
      } catch (_) {
        // Si falla la subida, se guarda el producto y se pueden agregar fotos luego.
      }
    }
    return uploaded;
  }

  Future<String?> _uploadProductImage(XFile image, String label) async {
    final business = context.read<BusinessInventoryCubit>().state.business;
    try {
      final bytes = await image.readAsBytes();
      final result = await sl<ApiClient>().post<Map<String, dynamic>>(
        '/storage/subir',
        data: {
          'archivo_base64': base64Encode(bytes),
          'nombre_archivo':
              'producto-$label-${DateTime.now().millisecondsSinceEpoch}.jpg',
          'content_type': 'image/jpeg',
          'bucket': 'productos',
          'scope': 'inventario',
          if (business != null) 'negocio_id': business.id,
        },
        parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
      );
      final url = result.data?['public_url']?.toString();
      if (result.isSuccess && url != null && url.isNotEmpty) return url;
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _pickPackageImage({required bool front}) async {
    final source = await _chooseImageSource();
    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 68,
      maxWidth: 960,
    );
    if (image == null || !mounted) return;
    setState(() {
      if (front) {
        _frontPackageImage = image;
        _image1File = image;
        _image1Controller.clear();
      } else {
        _backPackageImage = image;
        _image2File = image;
        _image2Controller.clear();
      }
    });
  }

  Future<void> _pickProductImage(int index) async {
    final source = await _chooseImageSource();
    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 72,
      maxWidth: 1080,
    );
    if (image == null || !mounted) return;
    setState(() {
      switch (index) {
        case 0:
          _image1File = image;
          _image1Controller.clear();
          break;
        case 1:
          _image2File = image;
          _image2Controller.clear();
          break;
        default:
          _image3File = image;
          _image3Controller.clear();
      }
    });
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar foto'),
                subtitle: const Text('Usar la camara del telefono'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir desde galeria'),
                subtitle: const Text('Usar una imagen guardada'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _detectPackageImages() async {
    final inventoryCubit = context.read<BusinessInventoryCubit>();
    setState(() => _detecting = true);
    try {
      final frontBytes = await _frontPackageImage?.readAsBytes();
      final backBytes = await _backPackageImage?.readAsBytes();
      var detection = await const LocalProductOcrService().detectPackage(
        frontImagePath: _frontPackageImage?.path,
        backImagePath: _backPackageImage?.path,
      );
      detection ??= await inventoryCubit.detectProductImages(
        frontImageBase64: frontBytes == null ? null : base64Encode(frontBytes),
        backImageBase64: backBytes == null ? null : base64Encode(backBytes),
      );
      if (!mounted || detection == null) return;
      final detected = detection;
      if (detected.name != null) _nameController.text = detected.name!;
      if (detected.brand != null) _brandController.text = detected.brand!;
      if (detected.description != null) {
        _descriptionController.text = detected.description!;
      }
      if (detected.category != null) {
        _categoryController.text = detected.category!;
      }
      if (detected.price != null) {
        _priceController.text = detected.price!.toStringAsFixed(2);
      }
      if (detected.currency != null &&
          ['CUP', 'MLC', 'USD'].contains(detected.currency)) {
        setState(() => _currency = detected.currency!);
      }
      final urls = detected.imageUrls;
      if (urls.isNotEmpty) {
        _image1Controller.text = urls.elementAtOrNull(0) ?? '';
        _image2Controller.text = urls.elementAtOrNull(1) ?? '';
        _image3Controller.text = urls.elementAtOrNull(2) ?? '';
      }
      setState(
        () => _detectedFeatures = detected.toProductFeatures(
          category: _categoryController.text,
        ),
      );
      await _loadPriceSuggestions();
      if (!mounted) return;
      if (detected.properties['fuente_deteccion'] == 'ocr_local') {
        showSnackOrAuthDialog(
          context,
          'Datos detectados localmente. Revisa antes de guardar.',
        );
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _loadPriceSuggestions() async {
    final signals =
        {
          'nombre_producto': _nameController.text.trim(),
          'marca': _brandController.text.trim(),
          'categoria_sugerida': _categoryController.text.trim(),
          'texto_detectado': _detectedFeatures['texto_detectado'],
          'limite': 6,
        }..removeWhere(
          (_, value) => value == null || value.toString().trim().isEmpty,
        );
    if (signals.length <= 1) return;
    setState(() => _loadingPriceSuggestions = true);
    try {
      final result = await sl<ApiClient>().post<Map<String, dynamic>>(
        '/productos/sugerencias-precio',
        data: signals,
        parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
      );
      final raw = result.data?['sugerencias'];
      if (!mounted || raw is! List) return;
      setState(() {
        _priceSuggestions = raw
            .whereType<Map>()
            .map((item) => _ProductPriceSuggestion.fromJson(item))
            .where((item) => item.price > 0)
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _priceSuggestions = const []);
    } finally {
      if (mounted) setState(() => _loadingPriceSuggestions = false);
    }
  }

  void _sendPatronFeedback(String patronId, bool acerto) {
    sl<ApiClient>()
        .post<Map<String, dynamic>>(
          '/productos/patron-feedback',
          data: {'patron_id': patronId, 'acerto': acerto},
          parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
        )
        .catchError((_) {});
  }
}

class _ProductPriceSuggestion {
  const _ProductPriceSuggestion({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.score,
    required this.source,
  });

  final String? id;
  final String name;
  final double price;
  final String currency;
  final num score;
  final String source;

  factory _ProductPriceSuggestion.fromJson(Map<dynamic, dynamic> json) {
    return _ProductPriceSuggestion(
      id: json['id']?.toString(),
      name: json['nombre']?.toString() ?? 'Producto similar',
      price: double.tryParse('${json['precio']}') ?? 0,
      currency: json['moneda']?.toString() ?? 'CUP',
      score: num.tryParse('${json['score'] ?? 0}') ?? 0,
      source: json['fuente']?.toString() ?? 'productos',
    );
  }
}

class _PriceSuggestionChips extends StatelessWidget {
  const _PriceSuggestionChips({
    required this.suggestions,
    required this.currency,
    required this.onUse,
  });

  final List<_ProductPriceSuggestion> suggestions;
  final String currency;
  final ValueChanged<_ProductPriceSuggestion> onUse;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.take(4).map((suggestion) {
        return ActionChip(
          avatar: const Icon(Icons.sell_outlined, size: 16),
          label: Text(
            '${suggestion.price.toStringAsFixed(0)} ${suggestion.currency.isEmpty ? currency : suggestion.currency}',
          ),
          tooltip: suggestion.name,
          onPressed: () => onUse(suggestion),
        );
      }).toList(),
    );
  }
}

class _PackageScanPanel extends StatelessWidget {
  const _PackageScanPanel({
    required this.frontImage,
    required this.backImage,
    required this.frontImageUrl,
    required this.backImageUrl,
    required this.detecting,
    required this.onPickFront,
    required this.onPickBack,
    required this.onAnalyze,
  });

  final XFile? frontImage;
  final XFile? backImage;
  final String? frontImageUrl;
  final String? backImageUrl;
  final bool detecting;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escaneo inteligente del empaque',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Toma o carga fotos del frente y reverso. La app lee el texto localmente y rellena marca, nombre, peso, tamano y detalles.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PackagePhotoButton(
                    title: 'Frente',
                    image: frontImage,
                    imageUrl: frontImageUrl,
                    onPressed: detecting ? null : onPickFront,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PackagePhotoButton(
                    title: 'Reverso',
                    image: backImage,
                    imageUrl: backImageUrl,
                    onPressed: detecting ? null : onPickBack,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: detecting ? null : onAnalyze,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Analizar y autocompletar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferPricePanel extends StatefulWidget {
  const _TransferPricePanel({
    required this.transferPriceController,
    required this.transferPercentController,
    required this.basePriceController,
    required this.currency,
  });

  final TextEditingController transferPriceController;
  final TextEditingController transferPercentController;
  final TextEditingController basePriceController;
  final String currency;

  @override
  State<_TransferPricePanel> createState() => _TransferPricePanelState();
}

class _TransferPricePanelState extends State<_TransferPricePanel> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    widget.basePriceController.addListener(_syncFromPercent);
    widget.transferPercentController.addListener(_syncFromPercent);
  }

  @override
  void didUpdateWidget(covariant _TransferPricePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.basePriceController != widget.basePriceController) {
      oldWidget.basePriceController.removeListener(_syncFromPercent);
      widget.basePriceController.addListener(_syncFromPercent);
    }
    if (oldWidget.transferPercentController !=
        widget.transferPercentController) {
      oldWidget.transferPercentController.removeListener(_syncFromPercent);
      widget.transferPercentController.addListener(_syncFromPercent);
    }
  }

  @override
  void dispose() {
    widget.basePriceController.removeListener(_syncFromPercent);
    widget.transferPercentController.removeListener(_syncFromPercent);
    super.dispose();
  }

  void _syncFromPercent() {
    if (_syncing) return;
    final base = double.tryParse(
      widget.basePriceController.text.trim().replaceAll(',', '.'),
    );
    final percent = double.tryParse(
      widget.transferPercentController.text.trim().replaceAll(',', '.'),
    );
    if (base == null || percent == null) return;
    final next = (base * (1 + percent / 100)).toStringAsFixed(2);
    if (widget.transferPriceController.text == next) return;
    _syncing = true;
    widget.transferPriceController.text = next;
    widget.transferPriceController.selection = TextSelection.collapsed(
      offset: widget.transferPriceController.text.length,
    );
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Precio por transferencia',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Puedes escribir el precio final por transferencia o solo el porcentaje de aumento sobre el precio normal.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.transferPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio transferencia',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: _optionalPositiveNumber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: widget.transferPercentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '% aumento',
                      prefixIcon: Icon(Icons.percent_outlined),
                    ),
                    validator: _optionalPositiveNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: Listenable.merge([
                widget.basePriceController,
                widget.transferPriceController,
                widget.transferPercentController,
              ]),
              builder: (context, _) {
                final preview = _previewTransferPrice();
                return Text(
                  preview == null
                      ? 'Si dejas ambos vacios, se mostrara solo el precio normal.'
                      : 'Vista previa: ${preview.toStringAsFixed(0)} ${widget.currency} por transferencia.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: preview == null
                        ? null
                        : Theme.of(context).colorScheme.secondary,
                    fontWeight: preview == null ? null : FontWeight.w800,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _optionalPositiveNumber(String? value) {
    final normalized = value?.trim().replaceAll(',', '.') ?? '';
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 0) return 'Valor invalido';
    return null;
  }

  double? _previewTransferPrice() {
    final direct = double.tryParse(
      widget.transferPriceController.text.trim().replaceAll(',', '.'),
    );
    if (direct != null) return direct;
    final base = double.tryParse(
      widget.basePriceController.text.trim().replaceAll(',', '.'),
    );
    final percent = double.tryParse(
      widget.transferPercentController.text.trim().replaceAll(',', '.'),
    );
    if (base == null || percent == null) return null;
    return base * (1 + percent / 100);
  }
}

class _PackagePhotoButton extends StatelessWidget {
  const _PackagePhotoButton({
    required this.title,
    required this.image,
    required this.imageUrl,
    required this.onPressed,
  });

  final String title;
  final XFile? image;
  final String? imageUrl;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null || (imageUrl?.isNotEmpty ?? false);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          image: image != null
              ? DecorationImage(
                  image: kIsWeb
                      ? NetworkImage(image!.path)
                      : FileImage(File(image!.path)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: image == null && (imageUrl?.isNotEmpty ?? false)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: hasImage ? Colors.black.withValues(alpha: 0.34) : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasImage
                            ? Icons.check_circle
                            : Icons.add_a_photo_outlined,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasImage ? '$title listo' : 'Foto $title',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProductImagePreviewRow extends StatelessWidget {
  const _ProductImagePreviewRow({
    required this.urls,
    required this.files,
    required this.onPick,
  });

  final List<String> urls;
  final List<XFile?> files;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: _ProductImageTile(
              label: index == 0 ? 'Principal' : 'Foto ${index + 1}',
              url: urls.elementAtOrNull(index),
              file: files.elementAtOrNull(index),
              onTap: () => onPick(index),
            ),
          ),
        );
      }),
    );
  }
}

class _ProductImageTile extends StatelessWidget {
  const _ProductImageTile({
    required this.label,
    required this.url,
    required this.file,
    required this.onTap,
  });

  final String label;
  final String? url;
  final XFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = file != null || (url?.isNotEmpty ?? false);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file != null)
                kIsWeb
                    ? Image.network(file!.path, fit: BoxFit.cover)
                    : Image.file(File(file!.path), fit: BoxFit.cover)
              else if (url?.isNotEmpty ?? false)
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                )
              else
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.add_photo_alternate_outlined),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: hasImage ? 0.34 : 0.08),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Puedes crear el negocio desde el wizard y volver a esta vista.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.lightTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
