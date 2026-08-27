import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../common/services/apk_update_service.dart';
import '../../../../common/presentation/widgets/update_download_sheet.dart';
import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/blocs/employee_access/employee_access_cubit.dart';
import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../business/data/models/business_employee_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _installedVersion;
  bool _checkingUpdates = false;
  bool _hasUpdate = false;
  String? _latestVersion;

  @override
  void initState() {
    super.initState();
    _loadInstalledVersion();
  }

  Future<void> _loadInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    final value = build.isEmpty ? info.version : '${info.version}+$build';
    if (!mounted) return;
    setState(() => _installedVersion = value);
  }

  Future<void> _checkUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final status = await sl<ApkUpdateService>().checkForUpdateStatus();
      if (!mounted) return;
      setState(() {
        _hasUpdate = status.hasUpdate;
        _latestVersion = status.latest?.version;
      });
      await _showUpdateModal(status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo verificar actualizaciones: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _showUpdateModal(ApkUpdateStatus status) async {
    final latest = status.latest;

    if (!status.hasUpdate || latest == null) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Estado de la APK'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version instalada: ${status.currentVersion}'),
                const SizedBox(height: 8),
                Text(
                  'Tu APK ya esta actualizada.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => UpdateDownloadSheet(update: latest),
    );
  }

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
                    const _EmployeeInvitesCard(),
                    if (session.isBusiness && activeMode == RoleMode.business)
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.businessDashboard),
                        icon: const Icon(Icons.dashboard_outlined),
                        label: const Text('Panel de mi negocio'),
                      )
                    else if (context.watch<EmployeeAccessCubit>().state.hasActiveMembership &&
                        activeMode == RoleMode.business)
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.businessDashboard),
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Panel del negocio (empleado)'),
                      )
                    else if ((session.isDelivery ||
                            context
                                .watch<EmployeeAccessCubit>()
                                .state
                                .hasDeliveryMembership) &&
                        activeMode == RoleMode.delivery)
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
          const _SectionLabel('Aplicación'),
          _ApkVersionCard(
            installedVersion: _installedVersion,
            checkingUpdates: _checkingUpdates,
            hasUpdate: _hasUpdate,
            latestVersion: _latestVersion,
            onCheckUpdates: _checkUpdates,
          ),
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
          icon: Icons.monetization_on_outlined,
          title: 'Billetera',
          subtitle: 'Saldo ConKkao, transferencias por alias/QR y movimientos.',
      onTap: () => context.go(AppRoutes.credits),
    ),
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
            icon: Icons.groups_outlined,
            title: 'Equipo',
            subtitle: 'Invitar empleados, cargos y permisos.',
            onTap: () => context.go(AppRoutes.businessTeam),
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

class _EmployeeInvitesCard extends StatelessWidget {
  const _EmployeeInvitesCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeeAccessCubit, EmployeeAccessState>(
      builder: (context, access) {
        if (access.pendingInvites.isEmpty && !access.hasActiveMembership) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (access.pendingInvites.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invitaciones de empleo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      ...access.pendingInvites.map(
                        (invite) => _PendingInviteTile(invite: invite),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (access.hasActiveMembership) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Negocios donde trabajas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      ...access.memberships.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.badge_outlined),
                          title: Text(item.businessName ?? 'Negocio'),
                          subtitle: Text(
                            [
                              item.roleTitle,
                              if (item.isDelivery) 'Delivery',
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await context.read<RoleModeCubit>().setMode(
                              RoleMode.business,
                            );
                            if (!context.mounted) return;
                            context.go(AppRoutes.businessDashboard);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class _PendingInviteTile extends StatefulWidget {
  const _PendingInviteTile({required this.invite});

  final BusinessEmployeeModel invite;

  @override
  State<_PendingInviteTile> createState() => _PendingInviteTileState();
}

class _PendingInviteTileState extends State<_PendingInviteTile> {
  var _busy = false;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await context.read<EmployeeAccessCubit>().respondToInvite(
      employeeId: widget.invite.id,
      accept: accept,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept
              ? 'Invitacion aceptada. Ya puedes usar el panel del negocio.'
              : 'Invitacion rechazada.',
        ),
      ),
    );
    if (accept) {
      await context.read<RoleModeCubit>().setMode(RoleMode.business);
      if (!mounted) return;
      context.go(AppRoutes.businessDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invite.businessName ?? 'Negocio',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text('Cargo: ${invite.roleTitle}'),
          if (invite.inviteMessage?.trim().isNotEmpty == true)
            Text(invite.inviteMessage!),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _respond(true),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

class _ApkVersionCard extends StatelessWidget {
  const _ApkVersionCard({
    required this.installedVersion,
    required this.checkingUpdates,
    required this.hasUpdate,
    required this.latestVersion,
    required this.onCheckUpdates,
  });

  final String? installedVersion;
  final bool checkingUpdates;
  final bool hasUpdate;
  final String? latestVersion;
  final VoidCallback onCheckUpdates;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Version APK',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (hasUpdate) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Nueva: $latestVersion',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              installedVersion == null
                  ? 'Cargando version instalada...'
                  : 'Instalada: $installedVersion',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: checkingUpdates ? null : onCheckUpdates,
              icon: checkingUpdates
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(hasUpdate ? Icons.system_update_alt_rounded : Icons.refresh_rounded),
              label: Text(hasUpdate ? 'Actualizar ahora' : 'Buscar actualizaciones'),
            ),
          ],
        ),
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
