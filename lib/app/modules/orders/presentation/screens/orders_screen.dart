import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/orders/orders_cubit.dart';
import '../../blocs/orders/orders_state.dart';
import '../../data/models/order_model.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({this.businessId, super.key});

  final String? businessId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersCubit>()..load(businessId: businessId),
      child: _OrdersView(businessId: businessId),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView({this.businessId});

  final String? businessId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          if (state.status == OrdersStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () =>
                context.read<OrdersCubit>().load(businessId: businessId),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  businessId == null ? 'Mis pedidos' : 'Pedidos del negocio',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  businessId == null
                      ? 'Solicitudes comerciales que enviaste.'
                      : 'Solicitudes recibidas por tu negocio.',
                ),
                const SizedBox(height: 18),
                if (state.status == OrdersStatus.failure)
                  _MessageCard(
                    icon: Icons.error_outline_rounded,
                    message: state.errorMessage ?? 'No se pudo cargar.',
                  )
                else if (state.items.isEmpty)
                  const _MessageCard(
                    icon: Icons.receipt_long_outlined,
                    message: 'Todavia no hay pedidos registrados.',
                  )
                else
                  ...state.items.map(_OrderCard.new),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.order);

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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [order.typeLabel, if (created != null) created].join(' - '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: order.statusLabel,
                  status: order.status,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              text: 'Contacto: ${order.contactName ?? 'Sin nombre'}',
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
                  _MetaChip(icon: Icons.inventory_2_outlined, label: 'Producto'),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, this.status});

  final String label;
  final String? status;

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
  const _MessageCard({required this.icon, required this.message});

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
