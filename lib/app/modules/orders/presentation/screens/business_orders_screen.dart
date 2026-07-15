import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/presentation/widgets/compact_date_range_dialog.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../common/services/contact_service.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/orders/orders_cubit.dart';
import '../../blocs/orders/orders_state.dart';
import '../../data/models/order_model.dart';

const _statusFilters = [
  _FilterOption('reservado_recogida', 'Reservado'),
  _FilterOption('reservado_delivery', 'Delivery'),
  _FilterOption('delivery_asignado', 'Delivery asignado'),
  _FilterOption('recogido_por_delivery', 'Recogido'),
  _FilterOption('solicitada', 'Solicitada'),
  _FilterOption('recibida', 'Recibida'),
  _FilterOption('preparando', 'Preparando'),
  _FilterOption('listo_para_recoger', 'Listo'),
  _FilterOption('en_ruta', 'En ruta'),
  _FilterOption('entregado_por_delivery', 'Entregado'),
  _FilterOption('recibido_cliente', 'Recibido por cliente'),
  _FilterOption('completado', 'Completado'),
  _FilterOption('nuevo', 'Nuevo'),
  _FilterOption('contactado', 'Contactado'),
  _FilterOption('en_proceso', 'En proceso'),
  _FilterOption('cerrado', 'Cerrado'),
  _FilterOption('cancelado', 'Cancelado'),
];

const _typeFilters = [
  _FilterOption('producto', 'Productos'),
  _FilterOption('propiedad', 'Propiedades'),
  _FilterOption('transporte', 'Transporte'),
  _FilterOption('servicio', 'Servicios'),
  _FilterOption('solicitud_red', 'Red'),
  _FilterOption('general', 'General'),
];

enum _DateFilter { all, today, last7, thisMonth }

class BusinessOrdersScreen extends StatelessWidget {
  const BusinessOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final businessId = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness
        ?.id;
    return BlocProvider(
      create: (_) {
        final cubit = sl<OrdersCubit>();
        if (businessId == null) {
          cubit.loadBusinessOrders();
        } else {
          cubit.load(businessId: businessId);
        }
        return cubit;
      },
      child: const _BusinessOrdersView(),
    );
  }
}

class _BusinessOrdersView extends StatefulWidget {
  const _BusinessOrdersView();

  @override
  State<_BusinessOrdersView> createState() => _BusinessOrdersViewState();
}

class _BusinessOrdersViewState extends State<_BusinessOrdersView> {
  String? _statusFilter;
  String? _typeFilter;
  _DateFilter _dateFilter = _DateFilter.all;
  String _clientQuery = '';
  DateTimeRange? _customRange;
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showSearch = !_showSearch),
        child: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
      ),
      body: BlocListener<ActiveBusinessCubit, ActiveBusinessState>(
        listenWhen: (previous, current) =>
            previous.activeBusiness?.id != current.activeBusiness?.id &&
            current.activeBusiness?.id != null,
        listener: (context, activeState) {
          final businessId = activeState.activeBusiness?.id;
          if (businessId != null) {
            context.read<OrdersCubit>().load(businessId: businessId);
          }
        },
        child: BlocConsumer<OrdersCubit, OrdersState>(
          listener: (context, state) {
            if (state.status == OrdersStatus.failure &&
                state.errorMessage != null) {
              showSnackOrAuthDialog(context, state.errorMessage);
            }
          },
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
                          'Pedidos recibidos',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pedidos y solicitudes de clientes hacia tu negocio.',
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.scanner),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Escanear QR de pedido'),
                        ),
                        if (_showSearch) ...[
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _clientQuery = value.trim()),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded),
                              labelText: 'Buscar pedido',
                              hintText: 'Cliente, titulo o estado',
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _BusinessOrderFilters(
                          statusFilter: _statusFilter,
                          typeFilter: _typeFilter,
                          dateFilter: _dateFilter,
                          customRange: _customRange,
                          onStatusChanged: (value) =>
                              setState(() => _statusFilter = value),
                          onTypeChanged: (value) =>
                              setState(() => _typeFilter = value),
                          onDateChanged: (value) =>
                              setState(() => _dateFilter = value),
                          onPickCustomRange: _pickCustomRange,
                          onClearCustomRange: _customRange == null
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
                        onRefresh: () {
                          final businessId = context
                              .read<ActiveBusinessCubit>()
                              .state
                              .activeBusiness
                              ?.id;
                          if (businessId == null) {
                            return context
                                .read<OrdersCubit>()
                                .loadBusinessOrders();
                          }
                          return context.read<OrdersCubit>().load(
                            businessId: businessId,
                          );
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          children: [
                            if (state.status == OrdersStatus.failure)
                              _MessageCard(
                                message:
                                    state.errorMessage ?? 'No se pudo cargar.',
                              )
                            else if (state.items.isEmpty)
                              const _MessageCard(
                                message: 'Todavia no hay pedidos recibidos.',
                              )
                            else if (visibleItems.isEmpty)
                              const _MessageCard(
                                message: 'No hay pedidos con esos filtros.',
                              )
                            else
                              ...visibleItems.map(
                                (order) => _BusinessOrderCard(order: order),
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
      ),
    );
  }

  bool _matchesFilters(OrderModel order) {
    final matchesStatus =
        _statusFilter == null || order.status == _statusFilter;
    final matchesType = _typeFilter == null || order.type == _typeFilter;
    final query = _clientQuery.toLowerCase();
    final searchable = [
      order.contactName,
      order.title,
      order.statusLabel,
      order.typeLabel,
      order.email,
    ].whereType<String>().join(' ').toLowerCase();
    final matchesClient = query.isEmpty || searchable.contains(query);
    final matchesDate = _matchesDate(order.createdAt);
    return matchesStatus && matchesType && matchesClient && matchesDate;
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
}

class _BusinessOrderFilters extends StatelessWidget {
  const _BusinessOrderFilters({
    required this.statusFilter,
    required this.typeFilter,
    required this.dateFilter,
    required this.customRange,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onPickCustomRange,
    required this.onClearCustomRange,
  });

  final String? statusFilter;
  final String? typeFilter;
  final _DateFilter dateFilter;
  final DateTimeRange? customRange;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<_DateFilter> onDateChanged;
  final VoidCallback onPickCustomRange;
  final VoidCallback? onClearCustomRange;

  @override
  Widget build(BuildContext context) {
    final currentStatus = _statusLabel(statusFilter);
    final currentType = _typeLabel(typeFilter);
    final currentDate = _dateLabel(dateFilter);
    final rangeLabel = customRange == null
        ? 'Fechas'
        : 'Fechas: ${_formatDate(customRange!.start)} - ${_formatDate(customRange!.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SelectActionButton(
                title: 'Estado',
                value: currentStatus,
                icon: Icons.tune_rounded,
                onPressed: () => _pickStatus(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SelectActionButton(
                title: 'Tipo',
                value: currentType,
                icon: Icons.category_outlined,
                onPressed: () => _pickType(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SelectActionButton(
                title: '',
                value: currentDate,
                icon: Icons.event_note_outlined,
                onPressed: () => _pickDate(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickCustomRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(rangeLabel, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        if (onClearCustomRange != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClearCustomRange,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Limpiar rango'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickStatus(BuildContext context) async {
    final selected = await _showSelectSheet<String>(
      context: context,
      title: 'Selecciona estado',
      options: [
        const _SelectOption(value: '', label: 'Todos'),
        ..._statusFilters.map(
          (item) => _SelectOption(value: item.value, label: item.label),
        ),
      ],
      currentValue: statusFilter ?? '',
    );
    if (selected == null) return;
    onStatusChanged(selected.isEmpty ? null : selected);
  }

  Future<void> _pickType(BuildContext context) async {
    final selected = await _showSelectSheet<String>(
      context: context,
      title: 'Selecciona tipo',
      options: [
        const _SelectOption(value: '', label: 'Todos'),
        ..._typeFilters.map(
          (item) => _SelectOption(value: item.value, label: item.label),
        ),
      ],
      currentValue: typeFilter ?? '',
    );
    if (selected == null) return;
    onTypeChanged(selected.isEmpty ? null : selected);
  }

  Future<void> _pickDate(BuildContext context) async {
    final selected = await _showSelectSheet<_DateFilter>(
      context: context,
      title: 'Selecciona fecha',
      options: const [
        _SelectOption(value: _DateFilter.all, label: 'Todo el tiempo'),
        _SelectOption(value: _DateFilter.today, label: 'Hoy'),
        _SelectOption(value: _DateFilter.last7, label: 'Ultimos 7 dias'),
        _SelectOption(value: _DateFilter.thisMonth, label: 'Este mes'),
      ],
      currentValue: dateFilter,
    );
    if (selected == null) return;
    onDateChanged(selected);
  }

  Future<T?> _showSelectSheet<T>({
    required BuildContext context,
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
    if (value == null) return 'Todos';
    for (final item in _statusFilters) {
      if (item.value == value) return item.label;
    }
    return 'Todos';
  }

  String _typeLabel(String? value) {
    if (value == null) return 'Todos';
    for (final item in _typeFilters) {
      if (item.value == value) return item.label;
    }
    return 'Todos';
  }

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

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}

class _BusinessOrderCard extends StatelessWidget {
  const _BusinessOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final total = order.estimatedTotal == null
        ? 'Consultar'
        : '${order.estimatedTotal!.toStringAsFixed(0)} ${order.currency ?? 'CUP'}';
    final created = order.createdAt == null
        ? null
        : '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}';
    final editableStatuses = _allowedStatusesFor(order);
    final selectedStatus = editableStatuses.contains(order.status)
        ? order.status
        : (editableStatuses.isEmpty ? null : editableStatuses.first);
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
                _StatusPill(status: order.status, label: order.statusLabel),
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
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  'Ver detalles y acciones',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                children: [
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    text: 'Cliente: ${order.contactName ?? 'Sin nombre'}',
                  ),
                  if (order.phone != null && order.phone!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      text: 'Telefono: ${order.phone}',
                    ),
                  if (order.email != null && order.email!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.mail_outline_rounded,
                      text: 'Email: ${order.email}',
                    ),
                  if (order.items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Productos del pedido',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'x${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: order.phone?.isNotEmpty == true
                              ? () => _openPhone(context)
                              : null,
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('Llamar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: order.phone?.isNotEmpty == true
                              ? () => _openWhatsApp(context)
                              : null,
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (selectedStatus != null)
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: editableStatuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null || value == order.status) return;
                        context.read<OrdersCubit>().updateStatus(
                          order.id,
                          value,
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _statusLabels = {
    'reservado_recogida': 'Reservado',
    'reservado_delivery': 'Reservado delivery',
    'solicitada': 'Solicitada',
    'recibida': 'Recibida',
    'confirmado_negocio': 'Confirmado',
    'preparando': 'Preparando',
    'listo_para_recoger': 'Listo para recoger',
    'delivery_asignado': 'Delivery asignado',
    'recogido_por_delivery': 'Recogido por delivery',
    'en_ruta': 'En ruta',
    'entregado_por_delivery': 'Entregado por delivery',
    'recibido_cliente': 'Recibido por cliente',
    'vendido_en_tienda': 'Vendido en tienda',
    'completado': 'Completado',
    'cancelado': 'Cancelado',
  };

  List<String> _allowedStatusesFor(OrderModel order) {
    final current = order.status ?? 'reservado_recogida';
    final isDeliveryOrder =
        order.status == 'reservado_delivery' ||
        order.status?.contains('delivery') == true;

    if (isDeliveryOrder) {
      return switch (current) {
        'reservado_delivery' ||
        'solicitada' ||
        'recibida' => [current, 'confirmado_negocio', 'cancelado'],
        'confirmado_negocio' => [
          current,
          'preparando',
          'delivery_asignado',
          'cancelado',
        ],
        'preparando' => [
          current,
          'listo_para_recoger',
          'delivery_asignado',
          'cancelado',
        ],
        'listo_para_recoger' => [
          current,
          'delivery_asignado',
          'recogido_por_delivery',
          'cancelado',
        ],
        'delivery_asignado' => [current, 'recogido_por_delivery', 'cancelado'],
        'recogido_por_delivery' => [current, 'en_ruta'],
        'en_ruta' => [current, 'entregado_por_delivery'],
        'entregado_por_delivery' ||
        'recibido_cliente' => [current, 'completado'],
        _ => [current],
      };
    }

    return switch (current) {
      'reservado_recogida' ||
      'solicitada' ||
      'recibida' => [current, 'confirmado_negocio', 'cancelado'],
      'confirmado_negocio' => [
        current,
        'preparando',
        'listo_para_recoger',
        'cancelado',
      ],
      'preparando' => [current, 'listo_para_recoger', 'cancelado'],
      'listo_para_recoger' => [
        current,
        'vendido_en_tienda',
        'completado',
        'cancelado',
      ],
      'vendido_en_tienda' => [current, 'completado'],
      _ => [current],
    };
  }

  String _statusLabel(String status) {
    return _statusLabels[status] ?? status;
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'producto' => Icons.inventory_2_outlined,
      'propiedad' => Icons.home_work_outlined,
      'transporte' => Icons.local_shipping_outlined,
      'servicio' => Icons.handyman_outlined,
      'solicitud_red' => Icons.hub_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }

  Future<void> _openPhone(BuildContext context) async {
    final message = await sl<ContactService>().openPhone(order.phone);
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final message = await sl<ContactService>().openWhatsApp(
      order.phone,
      message:
          'Hola ${order.contactName ?? ''}, te escribo por tu solicitud en CubNex.',
    );
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.label});

  final String? status;
  final String label;

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
      'preparando' ||
      'en_proceso' => _StatusVisual(Colors.orange, Icons.sync_rounded),
      'contactado' ||
      'confirmado_negocio' ||
      'listo_para_recoger' => _StatusVisual(
        Theme.of(context).colorScheme.secondary,
        Icons.storefront_rounded,
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
