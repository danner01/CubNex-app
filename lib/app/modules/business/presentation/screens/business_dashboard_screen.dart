import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
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
                business?.name == null || business!.name.trim().isEmpty
                    ? 'Panel de negocio'
                    : 'Hola, ${business.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Resumen de $roleLabel. Inventario, equipo y ficha siguen en acciones rapidas.',
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
    final logo = summary.business.logoUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              backgroundImage: logo == null || logo.isEmpty ? null : NetworkImage(logo),
              child: logo == null || logo.isEmpty
                  ? const Icon(Icons.storefront_rounded)
                  : null,
            ),
            const Spacer(),
            Text(
              'Nivel ${summary.level.toUpperCase()}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Ventas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          _formatCompact(summary.sales),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${summary.points} pts · perfil ${(summary.completeness * 100).round()}% completo',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
        keyName: 'orders',
        label: 'Pedidos',
        value: _formatCompact(summary.orders),
        status: summary.orders > 0 ? 'En curso' : 'Sin pedidos',
        icon: Icons.receipt_long_rounded,
        tint: AppColors.greenLight,
        route: AppRoutes.businessOrders,
      ),
      _KpiData(
        keyName: 'subscribers',
        label: 'Suscritos',
        value: '${summary.subscribers}',
        status: summary.recentSubscribers > 0
            ? '+${summary.recentSubscribers} / 30d'
            : 'Lista voluntaria',
        icon: Icons.people_alt_rounded,
        tint: AppColors.gold,
        route: AppRoutes.businessCustomers,
      ),
      _KpiData(
        keyName: 'potential',
        label: 'Potenciales',
        value: _formatCompact(summary.potentialCustomers),
        status: summary.potentialCustomers > 0
            ? 'Demanda de zona'
            : 'Sin umbral aun',
        icon: Icons.bubble_chart_rounded,
        tint: AppColors.blue,
        onTap: (context) => _showPotentialsSheet(context, summary),
      ),
      _KpiData(
        keyName: 'reviews',
        label: 'Resenas',
        value: '${summary.reviews}',
        status: '${summary.conversionPercent}% conversion',
        icon: Icons.star_rounded,
        tint: AppColors.green,
        route: AppRoutes.businessStore,
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
          'Indicadores con una sola accion. Catalogo y equipo estan en acciones rapidas.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 640 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 148,
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
    required this.icon,
    required this.tint,
    this.route,
    this.onTap,
  });

  final String keyName;
  final String label;
  final String value;
  final String status;
  final IconData icon;
  final Color tint;
  final String? route;
  final void Function(BuildContext context)? onTap;
}

Future<void> _showPotentialsSheet(
  BuildContext context,
  BusinessDashboardSummary summary,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clientes potenciales',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatCompact(summary.potentialCustomers)} personas con interes agregado en tu zona.',
              style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Es demanda anonima (preferencias y actividad de zona). No mostramos identidades, compras ni reservas individuales. Si sale 0, aun no hay umbral minimo de privacidad.',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.go(AppRoutes.businessCustomers);
              },
              child: const Text('Ver clientes suscritos'),
            ),
          ],
        ),
      );
    },
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item, required this.trend});

  final _KpiData item;
  final int trend;

  @override
  Widget build(BuildContext context) {
    final trendIcon = trend > 0
        ? Icons.trending_up_rounded
        : trend < 0
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    return Material(
      color: item.tint.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (item.onTap != null) {
            item.onTap!(context);
            return;
          }
          if (item.route != null) context.go(item.route!);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(item.icon, color: item.tint),
                  const Spacer(),
                  Icon(trendIcon, size: 18, color: item.tint),
                ],
              ),
              const Spacer(),
              Text(
                item.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                item.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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

