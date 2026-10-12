import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/entities/employee_permissions.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../home/data/models/business_model.dart';
import '../../../plans/presentation/widgets/active_plan_card.dart';
import '../../blocs/dashboard/business_dashboard_cubit.dart';
import '../../blocs/dashboard/business_dashboard_state.dart';
import '../../data/models/business_dashboard_summary.dart';
import '../../data/models/business_opportunity.dart';
import '../widgets/business_switcher.dart';

String _formatCompact(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  }
  return '$value';
}

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessDashboardCubit>()
        ..load(
          selectedBusiness: context.read<ActiveBusinessCubit>().state.activeBusiness,
        ),
      child: const _BusinessDashboardView(),
    );
  }
}

class _BusinessDashboardView extends StatelessWidget {
  const _BusinessDashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<ActiveBusinessCubit, ActiveBusinessState>(
        listenWhen: (previous, current) =>
            previous.activeBusiness?.id != current.activeBusiness?.id &&
            current.activeBusiness?.id != null,
        listener: (context, activeState) {
          context.read<BusinessDashboardCubit>().load(
            selectedBusiness: activeState.activeBusiness,
          );
        },
        child: BlocConsumer<BusinessDashboardCubit, BusinessDashboardState>(
          listenWhen: (previous, current) => previous.needsWizard != current.needsWizard,
          listener: (context, state) {
            if (!state.needsWizard) return;
            final active = context.read<ActiveBusinessCubit>().state.activeBusiness;
            if (active?.isEmployeeAccess == true) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go(AppRoutes.businessWizard);
            });
          },
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () => context.read<BusinessDashboardCubit>().load(
                selectedBusiness: context.read<ActiveBusinessCubit>().state.activeBusiness,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  const _DashboardHeader(),
                  const SizedBox(height: 6),
                  BusinessSwitcher(
                    onChanged: () => context.read<BusinessDashboardCubit>().load(
                      selectedBusiness: context.read<ActiveBusinessCubit>().state.activeBusiness,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.status == BusinessDashboardStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.summary == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(state.message ?? 'Crea tu negocio para ver estadisticas.'),
                      ),
                    )
                  else ...[
                    _HeroSummary(summary: state.summary!),
                    const SizedBox(height: 14),
                    ActivePlanCard(plan: state.activePlan),
                    const SizedBox(height: 14),
                    if (state.canViewReports)
                      _CommercialSummary(
                        summary: state.summary!,
                        trends: state.metricTrends,
                      )
                    else
                      const _RestrictedReportsCard(),
                    const SizedBox(height: 14),
                    _NearbyOpportunitiesSection(
                      status: state.nearbyStatus,
                      message: state.nearbyMessage,
                      opportunities: state.nearbyOpportunities,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Gestion del negocio',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agrupada por proposito. Sin accesos repetidos.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _GroupedManagement(business: state.summary!.business),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final business = context.watch<ActiveBusinessCubit>().state.activeBusiness;
    final isOwner = business?.isOwnerAccess ?? true;
    final roleLabel = business?.isEmployeeAccess == true
        ? (business?.employeeRoleTitle?.trim().isNotEmpty == true
              ? business!.employeeRoleTitle!
              : 'Empleado')
        : 'Propietario';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel de negocio',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vista de $roleLabel. El resumen comercial y la gestion se adaptan a tus permisos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (isOwner)
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.businessWizard),
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Nuevo'),
          ),
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.summary});

  final BusinessDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  child: const Icon(Icons.storefront_rounded, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Nivel ${summary.level.toUpperCase()} · ${summary.points} pts',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: summary.completeness),
            const SizedBox(height: 8),
            Text(
              'Perfil ${(summary.completeness * 100).round()}% completo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RestrictedReportsCard extends StatelessWidget {
  const _RestrictedReportsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Tu rol no incluye reportes comerciales. Usa la gestion habilitada abajo. Pide ver_reportes al administrador si necesitas metricas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _CommercialSummary extends StatelessWidget {
  const _CommercialSummary({required this.summary, required this.trends});

  final BusinessDashboardSummary summary;
  final Map<String, int> trends;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _KpiData(
        keyName: 'sales',
        label: 'Ventas',
        value: _formatCompact(summary.sales),
        status: summary.sales > 0 ? 'Activo' : 'Sin movimiento',
        caption: 'Movimiento comercial acumulado',
        action: 'Ver mapa',
        route: AppRoutes.salesMap,
      ),
      _KpiData(
        keyName: 'orders',
        label: 'Pedidos y reservas',
        value: _formatCompact(summary.orders),
        status: summary.orders > 0 ? 'En curso' : 'En espera',
        caption: 'Solicitudes operativas del negocio',
        action: 'Gestionar',
        route: AppRoutes.businessOrders,
      ),
      _KpiData(
        keyName: 'subscribers',
        label: 'Clientes suscritos',
        value: '${summary.subscribers}',
        status: summary.recentSubscribers > 0
            ? '+${summary.recentSubscribers} en 30 dias'
            : 'Lista voluntaria',
        caption: '${summary.notifiedSubscribers} reciben avisos. Sin compras individuales.',
        action: 'Ver lista',
        route: AppRoutes.businessCustomers,
      ),
      _KpiData(
        keyName: 'potential',
        label: 'Clientes potenciales',
        value: _formatCompact(summary.potentialCustomers),
        status: summary.potentialCustomers > 0 ? 'Demanda agregada' : 'Privado / umbral',
        caption: 'Interes de zona, nunca identidades sin consentimiento.',
        action: 'Ver zona',
        route: AppRoutes.preferences,
      ),
      _KpiData(
        keyName: 'reviews',
        label: 'Resenas',
        value: '${summary.reviews}',
        status: summary.reviews > 0 ? 'Reputacion visible' : 'Sin resenas',
        caption: 'Validacion publica del negocio',
        action: 'Ver ficha',
        route: AppRoutes.businessStore,
      ),
      _KpiData(
        keyName: 'conversion',
        label: 'Conversion',
        value: '${summary.conversionPercent}%',
        status: summary.conversionPercent >= 20
            ? 'Saludable'
            : summary.subscribers == 0
                ? 'Sin base'
                : 'Por mejorar',
        caption: 'Pedidos respecto a clientes suscritos.',
        action: 'Publicar',
        route: AppRoutes.businessPosts,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen comercial',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cada indicador tiene una sola accion. No se repite en gestion.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 720
                ? 3
                : constraints.maxWidth > 520
                    ? 2
                    : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 168,
              ),
              itemBuilder: (context, index) {
                final item = metrics[index];
                return _KpiCard(item: item, trend: trends[item.keyName] ?? 0);
              },
            );
          },
        ),
      ],
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.keyName,
    required this.label,
    required this.value,
    required this.status,
    required this.caption,
    required this.action,
    required this.route,
  });

  final String keyName;
  final String label;
  final String value;
  final String status;
  final String caption;
  final String action;
  final String route;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item, required this.trend});

  final _KpiData item;
  final int trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trendIcon = trend > 0
        ? Icons.trending_up_rounded
        : trend < 0
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final trendColor = trend > 0
        ? scheme.primary
        : trend < 0
            ? scheme.error
            : scheme.outline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.label, style: Theme.of(context).textTheme.titleSmall),
                ),
                Icon(trendIcon, size: 18, color: trendColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(item.status, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                item.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go(item.route),
                child: Text(item.action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyOpportunitiesSection extends StatelessWidget {
  const _NearbyOpportunitiesSection({
    required this.status,
    required this.opportunities,
    this.message,
  });

  final NearbyOpportunityStatus status;
  final List<BusinessOpportunity> opportunities;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Oportunidades cercanas',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complementarios, demanda agregada y posibles alianzas. Puedes abrir, guardar o descartar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (status == NearbyOpportunityStatus.loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (status == NearbyOpportunityStatus.needsLocation)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message ?? 'Activa tu zona aproximada para ver oportunidades.'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.preferences),
                    child: const Text('Ir a preferencias'),
                  ),
                ],
              ),
            ),
          )
        else if (opportunities.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                message ?? 'No hay oportunidades cercanas por ahora.',
              ),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: opportunities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _OpportunityCard(opportunity: opportunities[index]);
              },
            ),
          ),
      ],
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity});

  final BusinessOpportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: opportunity.logoUrl == null || opportunity.logoUrl!.isEmpty
                        ? null
                        : NetworkImage(opportunity.logoUrl!),
                    child: opportunity.logoUrl == null || opportunity.logoUrl!.isEmpty
                        ? const Icon(Icons.storefront_outlined)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      opportunity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_kindLabel(opportunity.kind), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  opportunity.reason ??
                      '${_formatCompact(opportunity.potentialDemand)} personas con interes agregado.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.go(AppRoutes.store(opportunity.businessId)),
                    child: const Text('Abrir'),
                  ),
                  TextButton(
                    onPressed: () => context.read<BusinessDashboardCubit>().interactWithOpportunity(
                      businessId: opportunity.businessId,
                      action: 'guardar',
                    ),
                    child: Text(opportunity.saved ? 'Guardada' : 'Guardar'),
                  ),
                  TextButton(
                    onPressed: () => context.read<BusinessDashboardCubit>().interactWithOpportunity(
                      businessId: opportunity.businessId,
                      action: 'descartar',
                    ),
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _kindLabel(String kind) {
    return switch (kind) {
      'complementario' || 'comprar' || 'vender' => 'Complementario',
      'alianza' => 'Posible alianza',
      _ => 'Demanda cercana',
    };
  }
}

class _GroupedManagement extends StatelessWidget {
  const _GroupedManagement({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final groups = _groupsFor(business);
    if (groups.every((group) => group.actions.isEmpty)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            business.isEmployeeAccess
                ? 'No tienes acciones habilitadas en este negocio. Pide al admin que active permisos.'
                : 'No hay acciones disponibles.',
          ),
        ),
      );
    }

    return Column(
      children: groups
          .where((group) => group.actions.isNotEmpty)
          .map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(group.subtitle, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      ...group.actions.map(
                        (action) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(action.icon),
                          title: Text(action.label),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.go(action.route),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<_ManagementGroup> _groupsFor(BusinessModel business) {
    bool can(String permission) => business.canEmployee(permission);
    final catalog = <_BusinessAction>[
      if (can(EmployeePermissionKeys.gestionarInventario))
        const _BusinessAction('Inventario', Icons.inventory_2_outlined, AppRoutes.businessInventory),
      if (business.businessParentCategory == 'gastronomia' && can(EmployeePermissionKeys.gestionarMenus))
        const _BusinessAction('Menus QR', Icons.restaurant_menu_outlined, AppRoutes.businessMenus),
      if (business.businessParentCategory == 'inmobiliaria' && can(EmployeePermissionKeys.editarNegocio))
        const _BusinessAction('Propiedades', Icons.home_work_outlined, AppRoutes.businessProperties),
      if (business.businessParentCategory == 'transporte' && can(EmployeePermissionKeys.editarNegocio))
        const _BusinessAction('Transporte', Icons.local_shipping_outlined, AppRoutes.businessTransport),
    ];
    final growth = <_BusinessAction>[
      if (can(EmployeePermissionKeys.gestionarPublicaciones))
        const _BusinessAction('Publicaciones', Icons.post_add_outlined, AppRoutes.businessPosts),
      if (can(EmployeePermissionKeys.gestionarPromociones))
        const _BusinessAction('Promociones', Icons.campaign_outlined, AppRoutes.businessPromotions),
      if (can(EmployeePermissionKeys.gestionarEmpleos))
        const _BusinessAction('Empleos', Icons.work_outline_rounded, AppRoutes.businessJobs),
      if (can(EmployeePermissionKeys.gestionarRed))
        const _BusinessAction('Red y alianzas', Icons.hub_outlined, AppRoutes.businessNetwork),
    ];
    final operations = <_BusinessAction>[
      if (can(EmployeePermissionKeys.gestionarPedidos))
        const _BusinessAction('Pedidos', Icons.receipt_long_outlined, AppRoutes.businessOrders),
      if (can(EmployeePermissionKeys.escanearPedidos))
        const _BusinessAction('Escanear', Icons.qr_code_scanner_rounded, AppRoutes.scanner),
      if (can(EmployeePermissionKeys.gestionarEmpleados))
        const _BusinessAction('Equipo', Icons.groups_outlined, AppRoutes.businessTeam),
    ];
    final settings = <_BusinessAction>[
      if (can(EmployeePermissionKeys.editarNegocio))
        const _BusinessAction('Ficha y configuracion', Icons.storefront_outlined, AppRoutes.businessStore),
      if (business.isOwnerAccess)
        const _BusinessAction('Plan', Icons.workspace_premium_outlined, AppRoutes.businessPlans),
    ];

    return [
      _ManagementGroup('Catalogo', 'Productos, menus y activos del negocio.', catalog),
      _ManagementGroup('Crecimiento', 'Publicar, promocionar y conectar.', growth),
      _ManagementGroup('Operacion', 'Pedidos, equipo y herramientas del dia.', operations),
      _ManagementGroup('Configuracion', 'Apariencia, ficha y plan.', settings),
    ];
  }
}

class _ManagementGroup {
  const _ManagementGroup(this.title, this.subtitle, this.actions);

  final String title;
  final String subtitle;
  final List<_BusinessAction> actions;
}

class _BusinessAction {
  const _BusinessAction(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}
