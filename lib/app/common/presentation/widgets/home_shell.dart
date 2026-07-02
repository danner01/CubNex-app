import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/app_session/app_session_cubit.dart';
import '../../blocs/role_mode/role_mode_cubit.dart';
import '../../../config/routes/app_routes.dart';
import 'auth_required_dialog.dart';
import 'market_app_bar.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final roleMode = context.watch<RoleModeCubit>().state.activeMode;
    final items = _itemsForMode(roleMode);
    final expectedHome = _homeForMode(roleMode);
    final showBackButton = _shouldShowBackButton(location, items);

    if (_isModeHomeMismatch(location, roleMode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(expectedHome);
        }
      });
    }

    return Scaffold(
      appBar: MarketAppBar(
        showBackButton: showBackButton,
        fallbackLocation: expectedHome,
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFromLocation(location, items),
        onDestinationSelected: (index) {
          final session = context.read<AppSessionCubit>().state;
          final item = items[index];
          final isProtected = item.protected;
          if (isProtected && session.status == AppSessionStatus.guest) {
            showAuthRequiredDialog(context);
            return;
          }
          context.go(item.location);
        },
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  int _indexFromLocation(String location, List<_ShellItem> items) {
    final index = items.indexWhere((item) => location.startsWith(item.prefix));
    if (index >= 0) return index;
    return 0;
  }

  String _homeForMode(RoleMode mode) {
    return switch (mode) {
      RoleMode.business => AppRoutes.businessDashboard,
      RoleMode.delivery => AppRoutes.deliveryDashboard,
      RoleMode.client => AppRoutes.home,
    };
  }

  bool _isModeHomeMismatch(String location, RoleMode mode) {
    return switch (mode) {
      RoleMode.client =>
        location.startsWith('/business') || location.startsWith('/delivery'),
      RoleMode.business =>
        location == AppRoutes.home ||
            location == AppRoutes.cart ||
            location == AppRoutes.orders ||
            location == AppRoutes.promotions ||
            location.startsWith('/delivery'),
      RoleMode.delivery =>
        location == AppRoutes.home ||
            location == AppRoutes.cart ||
            location == AppRoutes.orders ||
            location == AppRoutes.promotions ||
            location.startsWith('/business'),
    };
  }

  bool _shouldShowBackButton(String location, List<_ShellItem> items) {
    final isNavigationDestination = items.any(
      (item) => location == item.location || location == item.prefix,
    );
    if (isNavigationDestination) return false;
    return location != AppRoutes.home;
  }

  List<_ShellItem> _itemsForMode(RoleMode mode) {
    return switch (mode) {
      RoleMode.business => const [
        _ShellItem(
          label: 'Panel',
          location: AppRoutes.businessDashboard,
          prefix: '/business/dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Pedidos',
          location: AppRoutes.businessOrders,
          prefix: '/business/orders',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Inventario',
          location: AppRoutes.businessInventory,
          prefix: '/business/inventory',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Negocio',
          location: AppRoutes.businessStore,
          prefix: AppRoutes.businessStore,
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Perfil',
          location: AppRoutes.profile,
          prefix: AppRoutes.profile,
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          protected: true,
        ),
      ],
      RoleMode.delivery => const [
        _ShellItem(
          label: 'Panel',
          location: AppRoutes.deliveryDashboard,
          prefix: '/delivery/dashboard',
          icon: Icons.delivery_dining_outlined,
          selectedIcon: Icons.delivery_dining_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Solicitudes',
          location: AppRoutes.deliveryRequests,
          prefix: '/delivery/requests',
          icon: Icons.notifications_active_outlined,
          selectedIcon: Icons.notifications_active_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Ruta',
          location: AppRoutes.deliveryRoute,
          prefix: '/delivery/route',
          icon: Icons.map_outlined,
          selectedIcon: Icons.map_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Entregas',
          location: AppRoutes.deliveryHistory,
          prefix: '/delivery/history',
          icon: Icons.history_outlined,
          selectedIcon: Icons.history_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Perfil',
          location: AppRoutes.deliveryProfile,
          prefix: '/delivery/profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          protected: true,
        ),
      ],
      RoleMode.client => const [
        _ShellItem(
          label: 'Inicio',
          location: AppRoutes.home,
          prefix: AppRoutes.home,
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        _ShellItem(
          label: 'Buscar',
          location: AppRoutes.search,
          prefix: AppRoutes.search,
          icon: Icons.search_outlined,
          selectedIcon: Icons.search,
        ),
        _ShellItem(
          label: 'Feed',
          location: AppRoutes.posts,
          prefix: AppRoutes.posts,
          icon: Icons.dynamic_feed_outlined,
          selectedIcon: Icons.dynamic_feed_rounded,
        ),
        _ShellItem(
          label: 'Pedidos',
          location: AppRoutes.orders,
          prefix: AppRoutes.orders,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          protected: true,
        ),
        _ShellItem(
          label: 'Perfil',
          location: AppRoutes.profile,
          prefix: AppRoutes.profile,
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          protected: true,
        ),
      ],
    };
  }
}

class _ShellItem {
  const _ShellItem({
    required this.label,
    required this.location,
    required this.prefix,
    required this.icon,
    required this.selectedIcon,
    this.protected = false,
  });

  final String label;
  final String location;
  final String prefix;
  final IconData icon;
  final IconData selectedIcon;
  final bool protected;
}
