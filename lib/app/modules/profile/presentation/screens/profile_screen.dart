import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../../config/routes/app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSessionCubit>().state;
    final roleMode = context.watch<RoleModeCubit>().state;
    final activeMode = roleMode.activeMode;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: const Icon(Icons.person_rounded, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.email ?? 'Invitado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rol: ${session.role.name}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (roleMode.canSwitch) ...[
            _ModeSwitcher(state: roleMode),
            const SizedBox(height: 14),
          ],
          if (session.isBusiness && activeMode == RoleMode.business)
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.businessDashboard),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Panel de mi negocio'),
            )
          else if (session.isDelivery && activeMode == RoleMode.delivery)
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.deliveryDashboard),
              icon: const Icon(Icons.delivery_dining_rounded),
              label: const Text('Panel delivery'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.businessWizard),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crear mi negocio'),
            ),
          const SizedBox(height: 18),
          ..._profileTilesForMode(context, activeMode),
          const SizedBox(height: 10),
          const _SectionLabel('Configuracion'),
          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'Preferencias',
            subtitle: 'Tema, categorias y privacidad.',
            onTap: () => context.go(AppRoutes.preferences),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<AppSessionCubit>().logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }
}

List<Widget> _profileTilesForMode(BuildContext context, RoleMode mode) {
  final common = [
    _ProfileTile(
      icon: Icons.notifications_none_rounded,
      title: 'Notificaciones',
      subtitle: 'Avisos, pedidos, promociones y mensajes del sistema.',
      onTap: () => context.go(AppRoutes.notifications),
    ),
  ];

  return switch (mode) {
    RoleMode.client => [
      const _SectionLabel('Actividad cliente'),
      _ProfileTile(
        icon: Icons.favorite_border_rounded,
        title: 'Favoritos',
        subtitle: 'Productos, negocios, servicios y delivery guardados.',
        onTap: () => context.go(AppRoutes.favorites),
      ),
      _ProfileTile(
        icon: Icons.receipt_long_outlined,
        title: 'Mis pedidos',
        subtitle: 'Reservas, compras y entregas solicitadas.',
        onTap: () => context.go(AppRoutes.orders),
      ),
      ...common,
      const SizedBox(height: 10),
      const _SectionLabel('Historial y reputacion'),
      _ProfileTile(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Historial de escaneos',
        subtitle: 'QR, productos y codigos consultados.',
        onTap: () => context.go(AppRoutes.scanHistory),
      ),
      _ProfileTile(
        icon: Icons.rate_review_outlined,
        title: 'Mis resenas',
        subtitle: 'Opiniones y calificaciones publicadas.',
        onTap: () => context.go(AppRoutes.myReviews),
      ),
      _ProfileTile(
        icon: Icons.workspace_premium_outlined,
        title: 'Puntos y nivel',
        subtitle: 'Gamificacion, sorteos y cashback.',
        onTap: () => context.go(AppRoutes.gamification),
      ),
    ],
    RoleMode.business => [
      const _SectionLabel('Operacion del negocio'),
      _ProfileTile(
        icon: Icons.dashboard_customize_outlined,
        title: 'Dashboard negocio',
        subtitle: 'Ventas, reservas, inventario y rendimiento.',
        onTap: () => context.go(AppRoutes.businessDashboard),
      ),
      _ProfileTile(
        icon: Icons.add_business_rounded,
        title: 'Crear otro negocio',
        subtitle: 'Nueva tienda, franquicia o servicio asociado a tu cuenta.',
        onTap: () => context.go(AppRoutes.businessWizard),
      ),
      _ProfileTile(
        icon: Icons.receipt_long_outlined,
        title: 'Pedidos recibidos',
        subtitle: 'Reservas, ventas, QR y entregas de tus negocios.',
        onTap: () => context.go(AppRoutes.businessOrders),
      ),
      _ProfileTile(
        icon: Icons.inventory_2_outlined,
        title: 'Inventario',
        subtitle: 'Productos, stock, precios y visibilidad.',
        onTap: () => context.go(AppRoutes.businessInventory),
      ),
      _ProfileTile(
        icon: Icons.campaign_outlined,
        title: 'Promociones',
        subtitle: 'Ofertas activas del negocio seleccionado.',
        onTap: () => context.go(AppRoutes.businessPromotions),
      ),
      _ProfileTile(
        icon: Icons.storefront_outlined,
        title: 'Negocio',
        subtitle: 'Marca, horarios, electricidad, delivery y apariencia.',
        onTap: () => context.go(AppRoutes.businessSettings),
      ),
      ...common,
    ],
    RoleMode.delivery => [
      const _SectionLabel('Operacion delivery'),
      _ProfileTile(
        icon: Icons.delivery_dining_outlined,
        title: 'Panel delivery',
        subtitle: 'Solicitudes, entregas activas, ingresos y reputacion.',
        onTap: () => context.go(AppRoutes.deliveryDashboard),
      ),
      _ProfileTile(
        icon: Icons.assignment_outlined,
        title: 'Solicitudes',
        subtitle: 'Ordenes disponibles para aceptar.',
        onTap: () => context.go(AppRoutes.deliveryRequests),
      ),
      _ProfileTile(
        icon: Icons.map_outlined,
        title: 'Ruta y mapa',
        subtitle: 'Entregas activas y ubicacion en tiempo real.',
        onTap: () => context.go(AppRoutes.deliveryRoute),
      ),
      _ProfileTile(
        icon: Icons.history_rounded,
        title: 'Historial de entregas',
        subtitle: 'Ordenes completadas, kilometros y pagos.',
        onTap: () => context.go(AppRoutes.deliveryHistory),
      ),
      _ProfileTile(
        icon: Icons.badge_outlined,
        title: 'Perfil delivery',
        subtitle: 'Vehiculo, tarifa, disponibilidad y zona.',
        onTap: () => context.go(AppRoutes.deliveryProfile),
      ),
      ...common,
    ],
  };
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.state});

  final RoleModeState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modo de uso',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.availableModes.map((mode) {
                final selected = state.activeMode == mode;
                return ChoiceChip(
                  selected: selected,
                  label: Text(_modeLabel(mode)),
                  avatar: Icon(_modeIcon(mode), size: 18),
                  onSelected: (_) async {
                    await context.read<RoleModeCubit>().setMode(mode);
                    if (!context.mounted) return;
                    context.go(_modeHome(mode));
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _modeLabel(RoleMode mode) {
    return switch (mode) {
      RoleMode.client => 'Cliente',
      RoleMode.business => 'Negocio',
      RoleMode.delivery => 'Delivery',
    };
  }

  IconData _modeIcon(RoleMode mode) {
    return switch (mode) {
      RoleMode.client => Icons.shopping_bag_outlined,
      RoleMode.business => Icons.storefront_outlined,
      RoleMode.delivery => Icons.delivery_dining_outlined,
    };
  }

  String _modeHome(RoleMode mode) {
    return switch (mode) {
      RoleMode.client => AppRoutes.home,
      RoleMode.business => AppRoutes.businessDashboard,
      RoleMode.delivery => AppRoutes.deliveryDashboard,
    };
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
