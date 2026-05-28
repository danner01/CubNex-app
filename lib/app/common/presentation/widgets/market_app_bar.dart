import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';

class MarketAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarketAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? AppColors.gold : AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: isDark ? AppColors.ink : AppColors.gold,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CubNex',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    'CUBA',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isDark ? AppColors.greenLight : AppColors.green,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
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
            _HeaderButton(
              tooltip: 'Carrito',
              icon: Icons.shopping_cart_outlined,
              onPressed: () => context.go(AppRoutes.cart),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

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
            child: Icon(icon, size: 28),
          ),
        ),
      ),
    );
  }
}
