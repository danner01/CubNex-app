import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../common/services/contact_service.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/orders/orders_cubit.dart';
import '../../blocs/orders/orders_state.dart';
import '../../data/models/order_model.dart';

const _statusFilters = [
  _FilterOption('reservado_recogida', 'Reservado'),
  _FilterOption('reservado_delivery', 'Delivery'),
  _FilterOption('preparando', 'Preparando'),
  _FilterOption('listo_para_recoger', 'Listo'),
  _FilterOption('en_ruta', 'En ruta'),
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
  _FilterOption('general', 'General'),
];

class BusinessOrdersScreen extends StatelessWidget {
  const BusinessOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersCubit>()..loadBusinessOrders(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<OrdersCubit, OrdersState>(
        listener: (context, state) {
          if (state.status == OrdersStatus.failure &&
              state.errorMessage != null) {
            showSnackOrAuthDialog(context, state.errorMessage);
          }
        },
        builder: (context, state) {
          final visibleItems = state.items.where(_matchesFilters).toList();

          return RefreshIndicator(
            onRefresh: () => context.read<OrdersCubit>().loadBusinessOrders(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Pedidos recibidos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Solicitudes de clientes hacia tu negocio.'),
                const SizedBox(height: 14),
                _BusinessOrderFilters(
                  statusFilter: _statusFilter,
                  typeFilter: _typeFilter,
                  onStatusChanged: (value) =>
                      setState(() => _statusFilter = value),
                  onTypeChanged: (value) => setState(() => _typeFilter = value),
                ),
                const SizedBox(height: 18),
                if (state.status == OrdersStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.status == OrdersStatus.failure)
                  _MessageCard(
                    message: state.errorMessage ?? 'No se pudo cargar.',
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
    );
  }

  bool _matchesFilters(OrderModel order) {
    final matchesStatus =
        _statusFilter == null || order.status == _statusFilter;
    final matchesType = _typeFilter == null || order.type == _typeFilter;
    return matchesStatus && matchesType;
  }
}

class _BusinessOrderFilters extends StatelessWidget {
  const _BusinessOrderFilters({
    required this.statusFilter,
    required this.typeFilter,
    required this.onStatusChanged,
    required this.onTypeChanged,
  });

  final String? statusFilter;
  final String? typeFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: statusFilter == null,
                onTap: () => onStatusChanged(null),
              ),
              ..._statusFilters.map(
                (item) => _FilterChip(
                  label: item.label,
                  selected: statusFilter == item.value,
                  onTap: () => onStatusChanged(item.value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Todo tipo',
                selected: typeFilter == null,
                onTap: () => onTypeChanged(null),
              ),
              ..._typeFilters.map(
                (item) => _FilterChip(
                  label: item.label,
                  selected: typeFilter == item.value,
                  onTap: () => onTypeChanged(item.value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  child: Icon(_iconFor(order.type)),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 12),
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
            if (order.message != null && order.message!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(order.message!),
              ),
            ],
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Items reservados',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
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
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.tag_rounded,
                  label: 'Cantidad ${order.quantity ?? 1}',
                ),
                _MetaChip(
                  icon: Icons.payments_outlined,
                  label: total,
                  highlight: true,
                ),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: order.phone?.isNotEmpty == true
                        ? () => _openPhone(context)
                        : null,
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Llamar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: order.phone?.isNotEmpty == true
                        ? () => _openWhatsApp(context)
                        : null,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _allowedStatuses.contains(order.status)
                  ? order.status
                  : 'nuevo',
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(
                  value: 'reservado_recogida',
                  child: Text('Reservado'),
                ),
                DropdownMenuItem(
                  value: 'confirmado_negocio',
                  child: Text('Confirmado'),
                ),
                DropdownMenuItem(
                  value: 'preparando',
                  child: Text('Preparando'),
                ),
                DropdownMenuItem(
                  value: 'listo_para_recoger',
                  child: Text('Listo para recoger'),
                ),
                DropdownMenuItem(
                  value: 'vendido_en_tienda',
                  child: Text('Vendido en tienda'),
                ),
                DropdownMenuItem(
                  value: 'completado',
                  child: Text('Completado'),
                ),
                DropdownMenuItem(value: 'nuevo', child: Text('Nuevo')),
                DropdownMenuItem(
                  value: 'contactado',
                  child: Text('Contactado'),
                ),
                DropdownMenuItem(
                  value: 'en_proceso',
                  child: Text('En proceso'),
                ),
                DropdownMenuItem(value: 'cerrado', child: Text('Cerrado')),
                DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
              ],
              onChanged: (value) {
                if (value == null || value == order.status) return;
                context.read<OrdersCubit>().updateStatus(order.id, value);
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _allowedStatuses = {
    'nuevo',
    'contactado',
    'en_proceso',
    'cerrado',
    'cancelado',
    'reservado_recogida',
    'reservado_delivery',
    'confirmado_negocio',
    'preparando',
    'listo_para_recoger',
    'vendido_en_tienda',
    'completado',
  };

  IconData _iconFor(String? type) {
    return switch (type) {
      'producto' => Icons.inventory_2_outlined,
      'propiedad' => Icons.home_work_outlined,
      'transporte' => Icons.local_shipping_outlined,
      'servicio' => Icons.handyman_outlined,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
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
    final color = _colorFor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }

  Color _colorFor(BuildContext context, String? status) {
    return switch (status) {
      'cerrado' => Colors.green,
      'cancelado' => Theme.of(context).colorScheme.error,
      'en_proceso' => Colors.orange,
      'contactado' => Theme.of(context).colorScheme.secondary,
      _ => Theme.of(context).colorScheme.primary,
    };
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
