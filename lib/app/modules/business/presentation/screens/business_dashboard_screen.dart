import 'dart:math' as math;

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
import '../../data/models/business_operational_references.dart';
import '../../data/models/business_dashboard_summary.dart';
import '../widgets/business_switcher.dart';

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessDashboardCubit>()
        ..load(
          selectedBusiness: context
              .read<ActiveBusinessCubit>()
              .state
              .activeBusiness,
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
          listenWhen: (previous, current) =>
              previous.needsWizard != current.needsWizard,
          listener: (context, state) {
            if (!state.needsWizard) return;
            final active = context
                .read<ActiveBusinessCubit>()
                .state
                .activeBusiness;
            // Employees must not be forced into the owner onboarding wizard.
            if (active?.isEmployeeAccess == true) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go(AppRoutes.businessWizard);
              }
            });
          },
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () => context.read<BusinessDashboardCubit>().load(
                selectedBusiness: context
                    .read<ActiveBusinessCubit>()
                    .state
                    .activeBusiness,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  const _DashboardHeader(),
                  const SizedBox(height: 6),
                  BusinessSwitcher(
                    onChanged: () =>
                        context.read<BusinessDashboardCubit>().load(
                          selectedBusiness: context
                              .read<ActiveBusinessCubit>()
                              .state
                              .activeBusiness,
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
                        child: Text(
                          state.message ??
                              'Crea tu negocio para ver estadisticas.',
                        ),
                      ),
                    )
                  else ...[
                    _HeroSummary(summary: state.summary!),
                    const SizedBox(height: 14),
                    ActivePlanCard(plan: state.activePlan),
                    const SizedBox(height: 14),
                    _PerformancePanel(
                      summary: state.summary!,
                      references: state.operationalReferences,
                    ),
                    const SizedBox(height: 14),
                    _MetricsGrid(summary: state.summary!),
                    const SizedBox(height: 18),
                    Text(
                      'Gestion',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActionsGrid(summary: state.summary!),
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
        : null;

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
                roleLabel == null
                    ? 'Gestiona una tienda, franquicia o servicio por separado.'
                    : 'Acceso como $roleLabel. Solo ves lo que el admin habilito.',
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

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});

  final BusinessDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = _metricsForBusiness(summary);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: InkWell(
            onTap: () => context.go(metric.route),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    metric.icon,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  Text(metric.label),
                  Text(
                    '${metric.value}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_BusinessMetric> _metricsForBusiness(BusinessDashboardSummary summary) {
    final category = summary.business.businessParentCategory;
    final metrics = [
      ('Productos', summary.products, Icons.inventory_2_outlined),
      ('Resenas', summary.reviews, Icons.star_border_rounded),
      ('Promos', summary.promotions, Icons.campaign_outlined),
      ('Ventas', summary.sales, Icons.payments_outlined),
    ];
    final result = metrics
        .map(
          (item) => _BusinessMetric(
            item.$1,
            item.$2,
            item.$3,
            _routeForMetric(item.$1),
          ),
        )
        .toList();

    if (category == 'gastronomia') {
      result.add(
        _BusinessMetric(
          'Menus',
          summary.menus,
          Icons.restaurant_menu_outlined,
          AppRoutes.businessMenus,
        ),
      );
    }
    if (category == 'inmobiliaria') {
      result.add(
        _BusinessMetric(
          'Propiedades',
          summary.properties,
          Icons.home_work_outlined,
          AppRoutes.businessProperties,
        ),
      );
    }
    if (category == 'transporte') {
      result.add(
        _BusinessMetric(
          'Transporte',
          summary.transport,
          Icons.local_shipping_outlined,
          AppRoutes.businessTransport,
        ),
      );
    }
    if (category == 'servicio') {
      result.add(
        _BusinessMetric(
          'Reservas',
          summary.sales,
          Icons.event_available_outlined,
          AppRoutes.businessOrders,
        ),
      );
    }

    return result;
  }

  String _routeForMetric(String label) {
    return switch (label) {
      'Productos' => AppRoutes.businessInventory,
      'Promos' => AppRoutes.businessPromotions,
      'Ventas' || 'Resenas' => AppRoutes.businessOrders,
      _ => AppRoutes.businessDashboard,
    };
  }
}

class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({required this.summary, this.references});

  final BusinessDashboardSummary summary;
  final BusinessOperationalReferences? references;

  @override
  Widget build(BuildContext context) {
    final refs =
        references ?? _referencesFor(summary.business.businessParentCategory);
    final metrics = [
      _OperationalMetricData(
        label: 'Ventas',
        value: summary.sales,
        icon: Icons.payments_outlined,
        reference: refs.sales,
        scale: _MetricScale.logarithmic,
        context: 'Movimiento comercial total',
      ),
      _OperationalMetricData(
        label: 'Productos',
        value: summary.products,
        icon: Icons.inventory_2_outlined,
        reference: refs.products,
        context: 'Catalogo activo',
      ),
      _OperationalMetricData(
        label: 'Resenas',
        value: summary.reviews,
        icon: Icons.star_rate_outlined,
        reference: refs.reviews,
        context: 'Validacion social del negocio',
      ),
      _OperationalMetricData(
        label: 'Promos',
        value: summary.promotions,
        icon: Icons.campaign_outlined,
        reference: refs.promotions,
        context: 'Actividad promocional reciente',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.query_stats_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resumen operativo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...metrics.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OperationalMetricRow(item: item),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cada indicador usa su propia referencia para una lectura visual mas estable.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  BusinessOperationalReferences _referencesFor(String? category) {
    return switch (category) {
      'gastronomia' => const BusinessOperationalReferences(
        sales: 90000,
        products: 120,
        reviews: 90,
        promotions: 20,
      ),
      'transporte' => const BusinessOperationalReferences(
        sales: 45000,
        products: 35,
        reviews: 55,
        promotions: 8,
      ),
      'inmobiliaria' => const BusinessOperationalReferences(
        sales: 180000,
        products: 28,
        reviews: 35,
        promotions: 6,
      ),
      'servicio' => const BusinessOperationalReferences(
        sales: 70000,
        products: 45,
        reviews: 70,
        promotions: 10,
      ),
      _ => const BusinessOperationalReferences(
        sales: 50000,
        products: 80,
        reviews: 40,
        promotions: 12,
      ),
    };
  }
}

class _OperationalMetricRow extends StatelessWidget {
  const _OperationalMetricRow({required this.item});

  final _OperationalMetricData item;

  @override
  Widget build(BuildContext context) {
    final ratio = item.normalized;
    final ratioColor = _colorForRatio(context, ratio);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                item.formattedValue,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SegmentedScaleBar(ratio: ratio, color: ratioColor),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.context,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ref ${item.formattedReference}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForRatio(BuildContext context, double ratio) {
    if (ratio < 0.25) return Theme.of(context).colorScheme.error;
    if (ratio < 0.6) return Theme.of(context).colorScheme.secondary;
    return Theme.of(context).colorScheme.primary;
  }
}

class _SegmentedScaleBar extends StatelessWidget {
  const _SegmentedScaleBar({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const segments = 12;
    final filled = (ratio * segments).round().clamp(0, segments);
    return Row(
      children: List.generate(segments, (index) {
        final isFilled = index < filled;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == segments - 1 ? 0 : 4),
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: isFilled
                  ? color.withValues(alpha: 0.92)
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
        );
      }),
    );
  }
}

enum _MetricScale { linear, logarithmic }

class _OperationalMetricData {
  const _OperationalMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.reference,
    required this.context,
    this.scale = _MetricScale.linear,
  });

  final String label;
  final int value;
  final IconData icon;
  final int reference;
  final String context;
  final _MetricScale scale;

  double get normalized {
    if (reference <= 0 || value <= 0) return 0;
    final v = value.toDouble();
    final r = reference.toDouble();
    if (scale == _MetricScale.logarithmic) {
      return (math.log(v + 1) / math.log(r + 1)).clamp(0, 1);
    }
    return (v / r).clamp(0, 1);
  }

  String get formattedValue => _formatCompact(value);

  String get formattedReference => _formatCompact(reference);

  static String _formatCompact(int n) {
    if (n >= 1000000) {
      final value = (n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1);
      return '${value}M';
    }
    if (n >= 1000) {
      final value = (n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1);
      return '${value}K';
    }
    return '$n';
  }
}

class _ActionsGrid extends StatelessWidget {
  const _ActionsGrid({required this.summary});

  final BusinessDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final business = summary.business;
    final actions = _actionsForBusiness(business);

    if (actions.isEmpty) {
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Card(
          child: InkWell(
            onTap: () => context.go(action.route),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 32),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_BusinessAction> _actionsForBusiness(BusinessModel business) {
    final parentCategory = business.businessParentCategory;
    final common = <_BusinessActionCandidate>[
      _BusinessActionCandidate(
        'Publicaciones',
        Icons.post_add_outlined,
        AppRoutes.businessPosts,
        EmployeePermissionKeys.gestionarPublicaciones,
      ),
      _BusinessActionCandidate(
        'Inventario',
        Icons.inventory_2_outlined,
        AppRoutes.businessInventory,
        EmployeePermissionKeys.gestionarInventario,
      ),
      _BusinessActionCandidate(
        'Negocio',
        Icons.storefront_outlined,
        AppRoutes.businessStore,
        EmployeePermissionKeys.editarNegocio,
      ),
      _BusinessActionCandidate(
        'Promos',
        Icons.campaign_outlined,
        AppRoutes.businessPromotions,
        EmployeePermissionKeys.gestionarPromociones,
      ),
      _BusinessActionCandidate(
        'Pedidos',
        Icons.receipt_long_outlined,
        AppRoutes.businessOrders,
        EmployeePermissionKeys.gestionarPedidos,
      ),
      _BusinessActionCandidate(
        'Equipo',
        Icons.groups_outlined,
        AppRoutes.businessTeam,
        EmployeePermissionKeys.gestionarEmpleados,
      ),
      _BusinessActionCandidate(
        'Conexiones',
        Icons.hub_outlined,
        AppRoutes.businessNetwork,
        EmployeePermissionKeys.gestionarRed,
      ),
      _BusinessActionCandidate(
        'Empleos',
        Icons.work_outline_rounded,
        AppRoutes.businessJobs,
        EmployeePermissionKeys.gestionarEmpleos,
      ),
      _BusinessActionCandidate(
        'Escanear',
        Icons.qr_code_scanner_rounded,
        AppRoutes.scanner,
        EmployeePermissionKeys.escanearPedidos,
      ),
    ];

    final categorySpecific = switch (parentCategory) {
      'gastronomia' => [
        _BusinessActionCandidate(
          'Menus QR',
          Icons.restaurant_menu_outlined,
          AppRoutes.businessMenus,
          EmployeePermissionKeys.gestionarMenus,
        ),
      ],
      'inmobiliaria' => [
        _BusinessActionCandidate(
          'Propiedades',
          Icons.home_work_outlined,
          AppRoutes.businessProperties,
          EmployeePermissionKeys.editarNegocio,
        ),
      ],
      'transporte' => [
        _BusinessActionCandidate(
          'Transporte',
          Icons.local_shipping_outlined,
          AppRoutes.businessTransport,
          EmployeePermissionKeys.editarNegocio,
        ),
      ],
      'servicio' => [
        _BusinessActionCandidate(
          'Reservas',
          Icons.event_available_outlined,
          AppRoutes.businessOrders,
          EmployeePermissionKeys.gestionarPedidos,
        ),
      ],
      _ => const <_BusinessActionCandidate>[],
    };

    return [...common, ...categorySpecific]
        .where((item) => business.canEmployee(item.permission))
        .map((item) => _BusinessAction(item.label, item.icon, item.route))
        .toList();
  }
}

class _BusinessActionCandidate {
  const _BusinessActionCandidate(
    this.label,
    this.icon,
    this.route,
    this.permission,
  );

  final String label;
  final IconData icon;
  final String route;
  final String permission;
}

class _BusinessAction {
  const _BusinessAction(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

class _BusinessMetric {
  const _BusinessMetric(this.label, this.value, this.icon, this.route);

  final String label;
  final int value;
  final IconData icon;
  final String route;
}
