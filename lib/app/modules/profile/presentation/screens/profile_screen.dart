import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../config/routes/app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSessionCubit>().state;

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
          if (session.isBusiness)
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.businessDashboard),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Panel de mi negocio'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.businessWizard),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crear mi negocio'),
            ),
          const SizedBox(height: 18),
          const _SectionLabel('Actividad'),
          _ProfileTile(
            icon: Icons.favorite_border_rounded,
            title: 'Favoritos',
            subtitle: 'Productos, tiendas y servicios guardados.',
            onTap: () => context.go(AppRoutes.favorites),
          ),
          _ProfileTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notificaciones',
            subtitle: 'Promociones, pedidos y avisos del sistema.',
            onTap: () => context.go(AppRoutes.notifications),
          ),
          _ProfileTile(
            icon: Icons.receipt_long_outlined,
            title: 'Mis pedidos',
            subtitle: 'Solicitudes enviadas a negocios.',
            onTap: () => context.go(AppRoutes.orders),
          ),
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
          const SizedBox(height: 10),
          const _SectionLabel('Configuracion'),
          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'Preferencias v2',
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
