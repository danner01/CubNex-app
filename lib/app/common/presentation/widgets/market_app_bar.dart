import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../../../modules/orders/blocs/cart/cart_cubit.dart';
import 'cubnex_logo.dart';

class MarketAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarketAppBar({super.key});

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
            _HeaderButton(
              tooltip: 'Notificaciones',
              icon: Icons.notifications_none_rounded,
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
              RoleMode.business => _HeaderButton(
                tooltip: 'Pedidos del negocio',
                icon: Icons.receipt_long_outlined,
                onPressed: () => context.go(AppRoutes.businessOrders),
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
