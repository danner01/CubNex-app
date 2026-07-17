import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/compact_date_range_dialog.dart';
import '../../../../common/presentation/widgets/order_qr_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/orders/orders_cubit.dart';
import '../../blocs/orders/orders_state.dart';
import '../../data/models/order_model.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({
    this.businessId,
    this.businessRequesterView = false,
    super.key,
  });

  final String? businessId;
  final bool businessRequesterView;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersCubit>()..load(businessId: businessId),
      child: _OrdersView(
        businessId: businessId,
        businessRequesterView: businessRequesterView,
      ),
    );
  }
}

enum _DateFilter { all, today, last7, thisMonth }

const _clientStatusFilters = [
  _StatusFilterOption(null, 'Todos'),
  _StatusFilterOption('reservado_recogida', 'Reservado'),
  _StatusFilterOption('reservado_delivery', 'Res. delivery'),
  _StatusFilterOption('solicitada', 'Solicitada'),
  _StatusFilterOption('recibida', 'Recibida'),
  _StatusFilterOption('confirmado_negocio', 'Confirmado'),
  _StatusFilterOption('preparando', 'Preparando'),
  _StatusFilterOption('listo_para_recoger', 'Listo'),
  _StatusFilterOption('delivery_asignado', 'Asignado'),
  _StatusFilterOption('recogido_por_delivery', 'Recogido'),
  _StatusFilterOption('en_ruta', 'En ruta'),
  _StatusFilterOption('entregado_por_delivery', 'Entregado'),
  _StatusFilterOption('recibido_cliente', 'Recibido'),
  _StatusFilterOption('vendido_en_tienda', 'Vendido'),
  _StatusFilterOption('completado', 'Completado'),
  _StatusFilterOption('cancelado', 'Cancelado'),
];

const _statusShortLabels = {
  'reservado_recogida': 'Reservado',
  'reservado_delivery': 'Res. delivery',
  'solicitada': 'Solicitada',
  'recibida': 'Recibida',
  'confirmado_negocio': 'Confirmado',
  'preparando': 'Preparando',
  'listo_para_recoger': 'Listo',
  'delivery_asignado': 'Asignado',
  'recogido_por_delivery': 'Recogido',
  'en_ruta': 'En ruta',
  'entregado_por_delivery': 'Entregado',
  'recibido_cliente': 'Recibido',
  'vendido_en_tienda': 'Vendido',
  'completado': 'Completado',
  'cancelado': 'Cancelado',
};

class _OrdersView extends StatefulWidget {
  const _OrdersView({this.businessId, required this.businessRequesterView});

  final String? businessId;
  final bool businessRequesterView;

  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  _DateFilter _dateFilter = _DateFilter.all;
  DateTimeRange? _customRange;
  bool _showSearch = false;
  String _searchQuery = '';
  String? _statusFilter;
  bool _handledScanRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScanRefresh();
    });
  }

  void _handleScanRefresh() {
    if (!mounted || _handledScanRefresh) return;
    final currentUri = GoRouterState.of(context).uri;
    final query = currentUri.queryParameters;
    if (query['scan'] != 'ok') return;
    _handledScanRefresh = true;

    final message = query['scan_msg'] ?? 'Pedido actualizado correctamente.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.read<OrdersCubit>().load(businessId: widget.businessId);

    final cleanParams = Map<String, String>.from(query)
      ..remove('scan')
      ..remove('scan_msg');
    final cleanUri = Uri(
      path: currentUri.path,
      queryParameters: cleanParams.isEmpty ? null : cleanParams,
    );
    context.replace(cleanUri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isBusinessIncomingOrders = widget.businessId != null;
    final title = isBusinessIncomingOrders
        ? 'Pedidos del negocio'
        : widget.businessRequesterView
        ? 'Mis pedidos como negocio'
        : 'Mis pedidos';
    final subtitle = isBusinessIncomingOrders
        ? 'Solicitudes recibidas por tu negocio.'
        : widget.businessRequesterView
        ? 'Pedidos y solicitudes que realizaste desde tu cuenta de negocio.'
        : 'Solicitudes comerciales que enviaste.';

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showSearch = !_showSearch),
        child: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
      ),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          final visibleItems = state.items.where(_matchesFilters).toList();

          return Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle),
                      if (!isBusinessIncomingOrders) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.scanner),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Escanear pedido'),
                        ),
                      ],
                      if (_showSearch) ...[
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) =>
                              setState(() => _searchQuery = value.trim()),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            labelText: 'Buscar pedido',
                            hintText: 'Producto, contacto o estado',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatusFilterBar(
                              value: _statusFilter,
                              onChanged: (value) =>
                                  setState(() => _statusFilter = value),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DateFilterBar(
                              value: _dateFilter,
                              onChanged: (value) =>
                                  setState(() => _dateFilter = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _CustomDateRangeBar(
                        range: _customRange,
                        onPick: _pickCustomRange,
                        onClear: _customRange == null
                            ? null
                            : () => setState(() => _customRange = null),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.status == OrdersStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return RefreshIndicator(
                      onRefresh: () => context.read<OrdersCubit>().load(
                        businessId: widget.businessId,
                      ),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (state.status == OrdersStatus.failure)
                            _MessageCard(
                              icon: Icons.error_outline_rounded,
                              message:
                                  state.errorMessage ?? 'No se pudo cargar.',
                            )
                          else if (state.items.isEmpty)
                            const _MessageCard(
                              icon: Icons.receipt_long_outlined,
                              message: 'Todavia no hay pedidos registrados.',
                            )
                          else if (visibleItems.isEmpty)
                            const _MessageCard(
                              icon: Icons.filter_alt_off_outlined,
                              message:
                                  'No hay pedidos en el rango de fecha seleccionado.',
                            )
                          else
                          ...visibleItems.map(
                            (order) =>
                                _OrderCard(order, businessId: widget.businessId),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesDate(DateTime? date) {
    if (date == null) {
      return _customRange == null && _dateFilter == _DateFilter.all;
    }
    if (_customRange != null) {
      final start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
      final end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day,
        23,
        59,
        59,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }
    if (_dateFilter == _DateFilter.all) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = DateTime(date.year, date.month, date.day);
    return switch (_dateFilter) {
      _DateFilter.today => value == today,
      _DateFilter.last7 => !value.isBefore(
        today.subtract(const Duration(days: 6)),
      ),
      _DateFilter.thisMonth =>
        value.year == today.year && value.month == today.month,
      _DateFilter.all => true,
    };
  }

  bool _matchesFilters(OrderModel order) {
    final query = _searchQuery.toLowerCase();
    final haystack = [
      order.title,
      order.contactName,
      order.email,
      order.statusLabel,
      order.typeLabel,
    ].whereType<String>().join(' ').toLowerCase();
    final matchesSearch = query.isEmpty || haystack.contains(query);
    final matchesStatus =
        _statusFilter == null || order.status == _statusFilter;
    return matchesSearch && matchesStatus && _matchesDate(order.createdAt);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showCompactDateRangeDialog(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialRange: _customRange,
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _dateFilter = _DateFilter.all;
    });
  }
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({required this.value, required this.onChanged});

  final _DateFilter value;
  final ValueChanged<_DateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_DateFilter>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Fecha'),
      items: const [
        DropdownMenuItem(value: _DateFilter.all, child: Text('Todo el tiempo')),
        DropdownMenuItem(value: _DateFilter.today, child: Text('Hoy')),
        DropdownMenuItem(
          value: _DateFilter.last7,
          child: Text('Ultimos 7 dias'),
        ),
        DropdownMenuItem(value: _DateFilter.thisMonth, child: Text('Este mes')),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Estado'),
      items: _clientStatusFilters
          .map(
            (option) => DropdownMenuItem<String?>(
              value: option.value,
              child: Text(option.label),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _CustomDateRangeBar extends StatelessWidget {
  const _CustomDateRangeBar({
    required this.range,
    required this.onPick,
    required this.onClear,
  });

  final DateTimeRange? range;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = range == null
        ? 'Rango personalizado'
        : '${_format(range!.start)} - ${_format(range!.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        if (onClear != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Limpiar rango'),
            ),
          ),
      ],
    );
  }

  String _format(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.order, {required this.businessId});

  final OrderModel order;
  final String? businessId;

  @override
  Widget build(BuildContext context) {
    final total = order.estimatedTotal == null
        ? 'Consultar'
        : '${order.estimatedTotal!.toStringAsFixed(0)} ${order.currency ?? 'CUP'}';
    final created = order.createdAt == null
        ? null
        : '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}';
    final imageUrl = order.primaryImageUrl;
    final hasQr = order.canShowQrAction;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  child: imageUrl == null
                      ? Icon(_iconFor(order.type), size: 18)
                      : ClipOval(
                          child: Image.network(
                            imageUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Icon(_iconFor(order.type), size: 18),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          order.typeLabel,
                          if (created != null) created,
                        ].join(' - '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusBadge(
                      label: _shortStatusLabel(order.status, order.statusLabel),
                      status: order.status,
                    ),
                    if (hasQr) ...[
                      const SizedBox(height: 6),
                      _QrActionChip(
                        onTap: () async {
                          await showOrderQrDialogForOrder(context, order);
                          if (!context.mounted) return;
                          await context.read<OrdersCubit>().load(
                            businessId: businessId,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (order.message != null && order.message!.isNotEmpty) ...[
              Text(
                order.message!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.person_outline_rounded,
                  label: order.contactName ?? 'Sin nombre',
                ),
                if (created != null)
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: created,
                  ),
                _MetaChip(
                  icon: Icons.tag_rounded,
                  label: 'Cantidad ${order.quantity ?? 1}',
                ),
                _MetaChip(
                  icon: Icons.payments_outlined,
                  label: total,
                  highlight: true,
                ),
                if (order.phone != null && order.phone!.isNotEmpty)
                  _MetaChip(icon: Icons.phone_outlined, label: order.phone!),
                if (order.productId != null)
                  _MetaChip(
                    icon: Icons.inventory_2_outlined,
                    label: 'Producto',
                  ),
                if (order.propertyId != null)
                  _MetaChip(icon: Icons.home_work_outlined, label: 'Propiedad'),
                if (order.transportId != null)
                  _MetaChip(
                    icon: Icons.local_shipping_outlined,
                    label: 'Transporte',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'producto' => Icons.inventory_2_outlined,
      'propiedad' => Icons.home_work_outlined,
      'transporte' => Icons.local_shipping_outlined,
      'servicio' => Icons.handyman_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrActionChip extends StatelessWidget {
  const _QrActionChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                'Ver QR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 14, color: visual.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: visual.color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  _StatusVisual _visualFor(BuildContext context, String? status) {
    return switch (status) {
      'cerrado' => _StatusVisual(Colors.green, Icons.check_circle_rounded),
      'cancelado' => _StatusVisual(
        Theme.of(context).colorScheme.error,
        Icons.cancel_rounded,
      ),
      'en_proceso' => _StatusVisual(Colors.orange, Icons.sync_rounded),
      'contactado' => _StatusVisual(
        Theme.of(context).colorScheme.secondary,
        Icons.support_agent_rounded,
      ),
      _ => _StatusVisual(
        Theme.of(context).colorScheme.primary,
        Icons.receipt_long_rounded,
      ),
    };
  }
}

class _StatusVisual {
  const _StatusVisual(this.color, this.icon);

  final Color color;
  final IconData icon;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              icon,
              size: 46,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterOption {
  const _StatusFilterOption(this.value, this.label);

  final String? value;
  final String label;
}

String _shortStatusLabel(String? status, String fallback) {
  if (status == null || status.isEmpty) return fallback;
  return _statusShortLabels[status] ?? fallback;
}
