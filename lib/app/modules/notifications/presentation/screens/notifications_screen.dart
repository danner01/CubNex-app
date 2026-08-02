import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
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

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<NotificationsCubit, NotificationsState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          final visibleItems = _unreadOnly
              ? state.items.where((item) => !item.read).toList()
              : state.items;

          return RefreshIndicator(
            onRefresh: () => context.read<NotificationsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          Text(
                            state.unreadCount == 1
                                ? '1 notificacion sin leer'
                                : '${state.unreadCount} notificaciones sin leer',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Marcar todas',
                      onPressed: state.unreadCount == 0
                          ? null
                          : () => context
                                .read<NotificationsCubit>()
                                .markAllAsRead(),
                      icon: const Icon(Icons.done_all_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: !_unreadOnly,
                      onSelected: (_) => setState(() => _unreadOnly = false),
                    ),
                    ChoiceChip(
                      label: Text('Sin leer (${state.unreadCount})'),
                      selected: _unreadOnly,
                      onSelected: (_) => setState(() => _unreadOnly = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (state.status == NotificationsStatus.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visibleItems.isEmpty)
                  _EmptyNotificationsCard(unreadOnly: _unreadOnly)
                else
                  ...visibleItems.map(
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

class _EmptyNotificationsCard extends StatelessWidget {
  const _EmptyNotificationsCard({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              unreadOnly
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_rounded,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              unreadOnly
                  ? 'No tienes notificaciones pendientes.'
                  : 'No tienes notificaciones por ahora.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: notification.read ? null : colorScheme.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openNotification(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: notification.read
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.secondary,
                foregroundColor: notification.read
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSecondary,
                child: Icon(_iconFor(notification.type)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox(width: 9, height: 9),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            date,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_normalizedLink(notification.link) != null)
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(BuildContext context) async {
    await context.read<NotificationsCubit>().markAsRead(notification.id);
    if (!context.mounted) return;

    final target = _normalizedLink(notification.link);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta notificacion no tiene una vista vinculada.'),
        ),
      );
      return;
    }

    context.go(target);
  }

  String? _normalizedLink(String? rawLink) {
    if (rawLink == null || rawLink.trim().isEmpty) return null;
    final parsedUri = Uri.tryParse(rawLink.trim());
    final link = parsedUri?.hasScheme == true
        ? parsedUri!.path
        : rawLink.trim();

    if (link == '/market/negocio/pedidos' ||
        link == '/market/business/orders' ||
        link == '/business/orders' ||
        link == AppRoutes.businessOrders) {
      return AppRoutes.businessOrders;
    }
    if (link == '/market/negocio/red' || link == AppRoutes.businessNetwork) {
      return AppRoutes.businessNetwork;
    }
    if (link == '/market/notificaciones' || link == AppRoutes.notifications) {
      return AppRoutes.notifications;
    }
 
    if (link == '/creditos' || link == AppRoutes.credits) {
      return AppRoutes.credits;
    }
 
    if (link == '/market/feed' || link == AppRoutes.posts) {
      return AppRoutes.posts;
    }    if (link == '/market/promociones' || link == AppRoutes.promotions) {
      return AppRoutes.promotions;
    }

    final marketBusinessMatch = RegExp(
      r'^/market/negocios/([^/?#]+)',
    ).firstMatch(link);
    if (marketBusinessMatch != null) {
      return AppRoutes.store(marketBusinessMatch.group(1)!);
    }

    final knownPrefixes = <String>[
      AppRoutes.home,
      AppRoutes.search,
      AppRoutes.cart,
      AppRoutes.orders,
      AppRoutes.notifications,
      AppRoutes.businessDashboard,
      AppRoutes.businessOrders,
      AppRoutes.businessInventory,
      AppRoutes.businessSettings,
      AppRoutes.businessPromotions,
      AppRoutes.businessNetwork,
      AppRoutes.deliveryDashboard,
      AppRoutes.deliveryRequests,
    ];

    if (knownPrefixes.any((prefix) => link == prefix)) return link;
    if (link.startsWith('/store/') ||
        link.startsWith('/product/') ||
        link.startsWith('/properties/') ||
        link.startsWith('/transport/')) {
      return link;
    }

    return null;
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'promocion' || 'marketing' => Icons.campaign_outlined,
      'nuevo_producto' => Icons.new_releases_outlined,
      'pedido' => Icons.receipt_long_outlined,
      'solicitud_red' => Icons.playlist_add_check_circle_outlined,
      'suscripcion' => Icons.storefront_outlined,
      'resena' => Icons.rate_review_outlined,
      'sorteo' || 'cashback' => Icons.card_giftcard_outlined,
      'creditos' || 'credito' || 'credito_recarga' || 'credito_transferencia' || 'credito_ganancia' || 'credito_deduccion' => Icons.account_balance_wallet_outlined,
      'nivel' => Icons.workspace_premium_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }
}
