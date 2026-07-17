import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../common/services/push_notification_service.dart';
import '../../../config/http/api_client.dart';
import '../../../config/injection/injection.dart';
import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../../../modules/notifications/data/models/notification_model.dart';
import '../../../modules/orders/blocs/cart/cart_cubit.dart';
import 'cubnex_logo.dart';

class MarketAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarketAppBar({
    super.key,
    this.showBackButton = false,
    this.fallbackLocation,
  });

  final bool showBackButton;
  final String? fallbackLocation;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final cartCount = context.watch<CartCubit>().state.totalItems;
    final roleMode = context.watch<RoleModeCubit>().state.activeMode;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            if (showBackButton) ...[
              _BackButton(fallbackLocation: fallbackLocation),
              const SizedBox(width: 8),
            ],
            const CubNexLogo(size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandWordmark(),
                  Text(
                    'CUBA',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isDark ? AppColors.greenLight : AppColors.green,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2.8,
                    ),
                  ),
                ],
              ),
            ),
            _UnreadNotificationsButton(
              onPressed: () => context.go(AppRoutes.notifications),
            ),
            const SizedBox(width: 8),
            switch (roleMode) {
              RoleMode.client => _HeaderButton(
                tooltip: 'Carrito',
                icon: Icons.shopping_cart_outlined,
                badgeCount: cartCount,
                onPressed: () => context.go(AppRoutes.cart),
              ),
              RoleMode.business => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderButton(
                    tooltip: 'Pedidos del negocio',
                    icon: Icons.storefront_outlined,
                    onPressed: () => context.go(AppRoutes.businessOrders),
                  ),
                  const SizedBox(width: 8),
                  _HeaderButton(
                    tooltip: 'Mis pedidos como negocio',
                    icon: Icons.shopping_cart_outlined,
                    onPressed: () => context.go(AppRoutes.businessMyOrders),
                  ),
                ],
              ),
              RoleMode.delivery => _HeaderButton(
                tooltip: 'Mis ordenes de delivery',
                icon: Icons.delivery_dining_outlined,
                onPressed: () => context.go(AppRoutes.deliveryRequests),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _UnreadNotificationsButton extends StatefulWidget {
  const _UnreadNotificationsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_UnreadNotificationsButton> createState() =>
      _UnreadNotificationsButtonState();
}

class _UnreadNotificationsButtonState extends State<_UnreadNotificationsButton>
    with WidgetsBindingObserver {
  final ApiClient _apiClient = sl<ApiClient>();
  final PushNotificationService _pushNotificationService =
      sl<PushNotificationService>();
  Timer? _timer;
  StreamSubscription<void>? _pushSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _pushSubscription = _pushNotificationService.notificationsChanged.listen(
      (_) => _loadUnreadCount(),
    );
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _loadUnreadCount(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pushSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    final token = await _apiClient.readAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      if (_unreadCount != 0) setState(() => _unreadCount = 0);
      return;
    }

    final result = await _apiClient.get<List<NotificationModel>>(
      '/notificaciones',
      queryParameters: {'limit': 50, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is! List) return const <NotificationModel>[];
        return json
            .whereType<Map>()
            .map(
              (item) =>
                  NotificationModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      },
    );
    if (!mounted || !result.isSuccess) return;

    final nextCount = (result.data ?? const <NotificationModel>[])
        .where((item) => !item.read)
        .length;
    if (nextCount != _unreadCount) {
      setState(() => _unreadCount = nextCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HeaderButton(
      tooltip: _unreadCount > 0
          ? '$_unreadCount notificaciones sin leer'
          : 'Notificaciones',
      icon: Icons.notifications_none_rounded,
      badgeCount: _unreadCount,
      onPressed: widget.onPressed,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.fallbackLocation});

  final String? fallbackLocation;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: 'Volver',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(fallbackLocation ?? AppRoutes.home);
          },
          child: SizedBox(
            width: 44,
            height: 54,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 21,
              color: primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
      height: 0.98,
      shadows: [
        Shadow(
          color: (isDark ? AppColors.gold : AppColors.ink).withValues(
            alpha: 0.22,
          ),
          blurRadius: 10,
        ),
      ],
    );

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(
            text: 'Cub',
            style: TextStyle(color: isDark ? Colors.white : AppColors.ink),
          ),
          const TextSpan(
            text: 'N',
            style: TextStyle(
              color: AppColors.gold,
              fontStyle: FontStyle.italic,
            ),
          ),
          TextSpan(
            text: 'ex',
            style: TextStyle(
              color: isDark ? AppColors.greenLight : AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 28),
                if (badgeCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
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
}
