import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/notifications/notifications_cubit.dart';
import '../../blocs/notifications/notifications_state.dart';
import '../../data/models/notification_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NotificationsCubit>()..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<NotificationsCubit, NotificationsState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<NotificationsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notificaciones',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text('${state.unreadCount} sin leer'),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Marcar todas',
                      onPressed: state.items.isEmpty
                          ? null
                          : () => context
                                .read<NotificationsCubit>()
                                .markAllAsRead(),
                      icon: const Icon(Icons.done_all_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (state.status == NotificationsStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No tienes notificaciones por ahora.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...state.items.map(
                    (item) => _NotificationTile(notification: item),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final date = notification.createdAt == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy HH:mm').format(notification.createdAt!);

    return Card(
      color: notification.read
          ? null
          : Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          child: Icon(_iconFor(notification.type)),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${notification.message}\n$date'),
        ),
        isThreeLine: true,
        trailing: notification.read
            ? null
            : const Icon(Icons.fiber_manual_record, size: 12),
        onTap: () async {
          await context.read<NotificationsCubit>().markAsRead(notification.id);
          if (!context.mounted) return;
          final link = notification.link;
          if (link != null && link.startsWith('/')) {
            context.go(link);
          }
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'promocion' || 'marketing' => Icons.campaign_outlined,
      'nuevo_producto' => Icons.new_releases_outlined,
      'pedido' => Icons.receipt_long_outlined,
      'suscripcion' => Icons.storefront_outlined,
      'resena' => Icons.rate_review_outlined,
      'sorteo' || 'cashback' => Icons.card_giftcard_outlined,
      'nivel' => Icons.workspace_premium_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }
}
