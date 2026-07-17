import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/compact_date_range_dialog.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../orders/blocs/orders/orders_cubit.dart';
import '../../../orders/blocs/orders/orders_state.dart';
import '../../../orders/data/models/order_model.dart';

enum DeliveryHubSection { dashboard, requests, route, history, profile }

enum _DateFilter { all, today, last7, thisMonth }

const _deliveryTrackedStatuses = {
  'reservado_delivery',
  'delivery_asignado',
  'recogido_por_delivery',
  'en_ruta',
  'entregado_por_delivery',
  'recibido_cliente',
  'completado',
  'cancelado',
};

const _deliveryStatusFiltersRequests = [
  _StatusOption(null, 'Todos'),
  _StatusOption('reservado_delivery', 'Reservado'),
  _StatusOption('delivery_asignado', 'Asignado'),
  _StatusOption('recogido_por_delivery', 'Recogido'),
  _StatusOption('en_ruta', 'En ruta'),
  _StatusOption('entregado_por_delivery', 'Entregado'),
];

const _deliveryStatusFiltersHistory = [
  _StatusOption(null, 'Todos'),
  _StatusOption('recibido_cliente', 'Recibido'),
  _StatusOption('completado', 'Completado'),
  _StatusOption('cancelado', 'Cancelado'),
];

const _deliveryShortStatusLabels = {
  'reservado_delivery': 'Reservado',
  'delivery_asignado': 'Asignado',
  'recogido_por_delivery': 'Recogido',
  'en_ruta': 'En ruta',
  'entregado_por_delivery': 'Entregado',
  'recibido_cliente': 'Recibido',
  'completado': 'Completado',
  'cancelado': 'Cancelado',
};

class DeliveryHubScreen extends StatelessWidget {
  const DeliveryHubScreen({required this.section, super.key});

  final DeliveryHubSection section;

  @override
  Widget build(BuildContext context) {
    if (section == DeliveryHubSection.requests ||
        section == DeliveryHubSection.history) {
      return BlocProvider(
        create: (_) => sl<OrdersCubit>()..load(),
        child: _DeliveryOrdersView(section: section),
      );
    }
    return _DeliveryStaticView(section: section);
  }
}

class _DeliveryOrdersView extends StatefulWidget {
  const _DeliveryOrdersView({required this.section});

  final DeliveryHubSection section;

  @override
  State<_DeliveryOrdersView> createState() => _DeliveryOrdersViewState();
}

class _DeliveryOrdersViewState extends State<_DeliveryOrdersView> {
  _DateFilter _dateFilter = _DateFilter.all;
  String _clientQuery = '';
  String? _statusFilter;
  DateTimeRange? _customRange;
  bool _showSearch = false;
  bool _handledScanRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScanRefresh());
  }

  void _handleScanRefresh() {
    if (!mounted || _handledScanRefresh) return;
    final currentUri = GoRouterState.of(context).uri;
    final query = currentUri.queryParameters;
    if (query['scan'] != 'ok') return;
    _handledScanRefresh = true;

    final message = query['scan_msg'] ?? 'Pedido actualizado correctamente.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.read<OrdersCubit>().load();

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
    final isRequests = widget.section == DeliveryHubSection.requests;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showSearch = !_showSearch),
        child: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
      ),
      body: BlocConsumer<OrdersCubit, OrdersState>(
        listener: (context, state) {
          if (state.status == OrdersStatus.failure &&
              state.errorMessage != null) {
            showSnackOrAuthDialog(context, state.errorMessage);
          }
        },
        builder: (context, state) {
          final scoped = state.items.where((order) {
            if (!_deliveryTrackedStatuses.contains(order.status)) return false;
            final closed = const {
              'completado',
              'cerrado',
              'cancelado',
              'recibido_cliente',
            }.contains(order.status);
            return isRequests ? !closed : closed;
          });
          final visible = scoped.where(_matchesFilters).toList();

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
                        isRequests
                            ? 'Solicitudes delivery'
                            : 'Historial delivery',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isRequests
                            ? 'Pedidos activos pendientes de recoger o entregar.'
                            : 'Pedidos cerrados, recibidos o cancelados.',
                      ),
                      if (_showSearch) ...[
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) =>
                              setState(() => _clientQuery = value.trim()),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            labelText: 'Buscar pedido',
                            hintText: 'Cliente o estado',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SelectActionButton(
                              title: 'Estado',
                              value: _statusLabel(_statusFilter),
                              icon: Icons.tune_rounded,
                              onPressed: _pickStatus,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SelectActionButton(
                              title: '',
                              value: _dateLabel(_dateFilter),
                              icon: Icons.event_note_outlined,
                              onPressed: _pickDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickCustomRange,
                              icon: const Icon(Icons.date_range_outlined),
                              label: Text(
                                _customRange == null
                                    ? 'Fechas'
                                    : 'Fechas: ${_formatDate(_customRange!.start)} - ${_formatDate(_customRange!.end)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_customRange != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _customRange = null),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Limpiar rango'),
                          ),
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
                      onRefresh: () => context.read<OrdersCubit>().load(),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (state.status == OrdersStatus.failure)
                            _MessageCard(
                              message:
                                  state.errorMessage ?? 'No se pudo cargar.',
                            )
                          else if (visible.isEmpty)
                            const _MessageCard(
                              message: 'No hay pedidos con esos filtros.',
                            )
                          else
                            ...visible.map(
                              (order) => _DeliveryOrderCard(order: order),
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

  bool _matchesFilters(OrderModel order) {
    final query = _clientQuery.toLowerCase();
    final searchable = [
      order.contactName,
      order.title,
      order.statusLabel,
      order.email,
    ].whereType<String>().join(' ').toLowerCase();
    final matchesClient = query.isEmpty || searchable.contains(query);
    final matchesStatus =
        _statusFilter == null || order.status == _statusFilter;
    return matchesClient && matchesStatus && _matchesDate(order.createdAt);
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

  Future<void> _pickStatus() async {
    final selected = await _showSelectSheet<String>(
      title: 'Selecciona estado',
      options: _statusOptions
          .map(
            (item) => _SelectOption(value: item.value ?? '', label: item.label),
          )
          .toList(),
      currentValue: _statusFilter ?? '',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _statusFilter = selected.isEmpty ? null : selected;
    });
  }

  Future<void> _pickDate() async {
    final selected = await _showSelectSheet<_DateFilter>(
      title: 'Selecciona fecha',
      options: const [
        _SelectOption(value: _DateFilter.all, label: 'Todo el tiempo'),
        _SelectOption(value: _DateFilter.today, label: 'Hoy'),
        _SelectOption(value: _DateFilter.last7, label: 'Ultimos 7 dias'),
        _SelectOption(value: _DateFilter.thisMonth, label: 'Este mes'),
      ],
      currentValue: _dateFilter,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _dateFilter = selected;
      _customRange = null;
    });
  }

  Future<T?> _showSelectSheet<T>({
    required String title,
    required List<_SelectOption<T>> options,
    required T currentValue,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ...options.map((item) {
                final selected = item.value == currentValue;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(item.label),
                  onTap: () => Navigator.of(sheetContext).pop(item.value),
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String? value) {
    for (final item in _statusOptions) {
      if ((item.value ?? '') == (value ?? '')) return item.label;
    }
    return 'Todos';
  }

  List<_StatusOption> get _statusOptions =>
      widget.section == DeliveryHubSection.requests
      ? _deliveryStatusFiltersRequests
      : _deliveryStatusFiltersHistory;

  String _dateLabel(_DateFilter value) {
    return switch (value) {
      _DateFilter.all => 'Todo el tiempo',
      _DateFilter.today => 'Hoy',
      _DateFilter.last7 => 'Ultimos 7 dias',
      _DateFilter.thisMonth => 'Este mes',
    };
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _DeliveryOrderCard extends StatelessWidget {
  const _DeliveryOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final total = order.estimatedTotal == null
        ? 'Consultar'
        : '${order.estimatedTotal!.toStringAsFixed(0)} ${order.currency ?? 'CUP'}';
    final created = order.createdAt == null
        ? '-'
        : '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}';
    final imageUrl = order.primaryImageUrl;

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
                _OrderThumbnail(
                  imageUrl: imageUrl,
                  fallbackIcon: _iconFor(order.type),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(
                  label: _shortDeliveryStatusLabel(
                    order.status,
                    order.statusLabel,
                  ),
                  status: order.status,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.person_outline_rounded,
                  label: order.contactName ?? 'Sin nombre',
                ),
                _MetaChip(icon: Icons.calendar_today_outlined, label: created),
                _MetaChip(icon: Icons.payments_outlined, label: total),
                _MetaChip(
                  icon: Icons.tag_rounded,
                  label: 'Cantidad ${order.quantity ?? 1}',
                ),
                if ((order.typeLabel).isNotEmpty)
                  _MetaChip(
                    icon: Icons.category_outlined,
                    label: order.typeLabel,
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

class _DeliveryStaticView extends StatelessWidget {
  const _DeliveryStaticView({required this.section});

  final DeliveryHubSection section;

  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      DeliveryHubSection.dashboard => 'Panel delivery',
      DeliveryHubSection.route => 'Ruta y mapa',
      DeliveryHubSection.profile => 'Perfil delivery',
      DeliveryHubSection.requests => 'Solicitudes',
      DeliveryHubSection.history => 'Historial delivery',
    };
    final subtitle = switch (section) {
      DeliveryHubSection.dashboard =>
        'Solicitudes, entregas y estado operativo.',
      DeliveryHubSection.route =>
        'Seguimiento en tiempo real y validaciones QR.',
      DeliveryHubSection.profile =>
        'Vehiculo, tarifas, verificacion y disponibilidad.',
      DeliveryHubSection.requests =>
        'Pedidos de tiendas y paquetes entre clientes.',
      DeliveryHubSection.history => 'Entregas cerradas y pedidos completados.',
    };

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _SelectActionButton extends StatelessWidget {
  const _SelectActionButton({
    required this.title,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
        ],
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectOption<T> {
  const _SelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.label});

  final String? status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = switch (status) {
      'completado' ||
      'cerrado' => _StatusVisual(Colors.green, Icons.check_circle_rounded),
      'cancelado' => _StatusVisual(
        Theme.of(context).colorScheme.error,
        Icons.cancel_rounded,
      ),
      'en_ruta' || 'delivery_asignado' || 'recogido_por_delivery' =>
        _StatusVisual(Colors.blue, Icons.local_shipping_rounded),
      'entregado_por_delivery' || 'recibido_cliente' => _StatusVisual(
        Colors.teal,
        Icons.qr_code_scanner_rounded,
      ),
      _ => _StatusVisual(
        Theme.of(context).colorScheme.primary,
        Icons.receipt_long_rounded,
      ),
    };
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
}

class _StatusVisual {
  const _StatusVisual(this.color, this.icon);

  final Color color;
  final IconData icon;
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.imageUrl, required this.fallbackIcon});

  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      foregroundColor: Theme.of(context).colorScheme.onSecondary,
      child: imageUrl == null
          ? Icon(fallbackIcon, size: 18)
          : ClipOval(
              child: Image.network(
                imageUrl!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(fallbackIcon, size: 18),
              ),
            ),
    );
  }
}

String _shortDeliveryStatusLabel(String? status, String fallback) {
  if (status == null || status.isEmpty) return fallback;
  return _deliveryShortStatusLabels[status] ?? fallback;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _StatusOption {
  const _StatusOption(this.value, this.label);

  final String? value;
  final String label;
}
