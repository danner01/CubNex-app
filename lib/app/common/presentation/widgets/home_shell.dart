import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../../blocs/active_business/active_business_cubit.dart';
import '../../blocs/app_session/app_session_cubit.dart';
import '../../blocs/role_mode/role_mode_cubit.dart';
import '../../entities/employee_permissions.dart';
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
    final showBackButton = _shouldShowBackButton(location, items, roleMode);

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
      bottomNavigationBar: roleMode == RoleMode.business
          ? _BusinessBottomBar(
              location: location,
              onOpenQuickActions: () => _showBusinessQuickActions(context),
            )
          : NavigationBar(
              selectedIndex: _indexFromLocation(location, items),
              onDestinationSelected: (index) {
                final session = context.read<AppSessionCubit>().state;
                final item = items[index];
                if (item.protected &&
                    session.status == AppSessionStatus.guest) {
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
            location == AppRoutes.posts ||
            location.startsWith('/delivery'),
      RoleMode.delivery =>
        location == AppRoutes.home ||
            location == AppRoutes.cart ||
            location == AppRoutes.orders ||
            location == AppRoutes.promotions ||
            location.startsWith('/business'),
    };
  }

  bool _shouldShowBackButton(
    String location,
    List<_ShellItem> items,
    RoleMode mode,
  ) {
    if (mode == RoleMode.business) {
      final isRoot =
          location == AppRoutes.businessDashboard ||
          location == AppRoutes.profile;
      return !isRoot;
    }

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
          label: 'Feed',
          location: AppRoutes.posts,
          prefix: AppRoutes.posts,
          icon: Icons.dynamic_feed_outlined,
          selectedIcon: Icons.dynamic_feed_rounded,
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

  Future<void> _showBusinessQuickActions(BuildContext context) async {
    final session = context.read<AppSessionCubit>().state;
    if (session.status == AppSessionStatus.guest) {
      showAuthRequiredDialog(context);
      return;
    }

    final business = context.read<ActiveBusinessCubit>().state.activeBusiness;
    bool can(String permission) =>
        business == null || business.canEmployee(permission);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final actions = <_QuickAction>[
          if (can(EmployeePermissionKeys.escanearPedidos))
            _QuickAction(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Escanear',
              subtitle: 'QR de pedidos o productos',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.scanner);
              },
            ),
          if (can(EmployeePermissionKeys.gestionarPedidos))
            _QuickAction(
              icon: Icons.receipt_long_rounded,
              label: 'Pedidos',
              subtitle: 'Gestionar solicitudes entrantes',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.businessOrders);
              },
            ),
          if (can(EmployeePermissionKeys.gestionarInventario))
            _QuickAction(
              icon: Icons.inventory_2_rounded,
              label: 'Inventario',
              subtitle: 'Productos y stock',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.businessInventory);
              },
            ),
          if (can(EmployeePermissionKeys.editarNegocio))
            _QuickAction(
              icon: Icons.storefront_rounded,
              label: 'Mi negocio',
              subtitle: 'Vista y apariencia de tienda',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.businessStore);
              },
            ),
          if (can(EmployeePermissionKeys.gestionarEmpleados))
            _QuickAction(
              icon: Icons.groups_rounded,
              label: 'Equipo',
              subtitle: 'Empleados y permisos',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.businessTeam);
              },
            ),
          if (can(EmployeePermissionKeys.gestionarPromociones))
            _QuickAction(
              icon: Icons.campaign_rounded,
              label: 'Promociones',
              subtitle: 'Ofertas y campanas',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.businessPromotions);
              },
            ),
          if (can(EmployeePermissionKeys.gestionarRed))
            _QuickAction(
              icon: Icons.hub_rounded,
              label: 'Red B2B',
            subtitle: 'Conexiones con otros negocios',
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.go(AppRoutes.businessNetwork);
            },
          ),
          if (can(EmployeePermissionKeys.pagosQr) ||
              can(EmployeePermissionKeys.pagosAlias) ||
              can(EmployeePermissionKeys.transferirCreditos))
            _QuickAction(
              icon: Icons.monetization_on_rounded,
              label: 'Billetera',
              subtitle: 'Saldo, cobros y transferencias',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.credits);
              },
            ),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acciones rapidas',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Atajos del panel de negocio',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: actions.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                    ),
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      return Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: action.onTap,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(action.icon, color: AppColors.goldDark),
                                const Spacer(),
                                Text(
                                  action.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  action.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BusinessBottomBar extends StatelessWidget {
  const _BusinessBottomBar({
    required this.location,
    required this.onOpenQuickActions,
  });

  final String location;
  final VoidCallback onOpenQuickActions;

  @override
  Widget build(BuildContext context) {
    final isPanel = location.startsWith('/business/dashboard') ||
        location == AppRoutes.businessDashboard;
    final isProfile = location.startsWith(AppRoutes.profile);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: Material(
          elevation: 8,
          color: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: _BusinessNavButton(
                    icon: isPanel
                        ? Icons.dashboard_rounded
                        : Icons.dashboard_outlined,
                    label: 'Panel',
                    selected: isPanel,
                    onTap: () => context.go(AppRoutes.businessDashboard),
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: Center(
                    child: Tooltip(
                      message: 'Acciones rapidas',
                      child: Material(
                        color: AppColors.gold,
                        shape: const CircleBorder(),
                        elevation: 4,
                        shadowColor: AppColors.gold.withValues(alpha: 0.45),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onOpenQuickActions,
                          child: const SizedBox(
                            width: 62,
                            height: 62,
                            child: Icon(
                              Icons.add_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _BusinessNavButton(
                    icon: isProfile ? Icons.person : Icons.person_outline,
                    label: 'Perfil',
                    selected: isProfile,
                    onTap: () => context.go(AppRoutes.profile),
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

class _BusinessNavButton extends StatelessWidget {
  const _BusinessNavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
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

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}
