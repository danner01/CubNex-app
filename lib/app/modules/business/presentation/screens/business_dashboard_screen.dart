import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/dashboard/business_dashboard_cubit.dart';
import '../../blocs/dashboard/business_dashboard_state.dart';
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
      body: BlocConsumer<BusinessDashboardCubit, BusinessDashboardState>(
        listenWhen: (previous, current) =>
            previous.needsWizard != current.needsWizard,
        listener: (context, state) {
          if (!state.needsWizard) return;
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
                Text(
                  'Panel de negocio',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                BusinessSwitcher(
                  onChanged: () => context.read<BusinessDashboardCubit>().load(
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
    final metrics = [
      ('Productos', summary.products, Icons.inventory_2_outlined),
      ('Resenas', summary.reviews, Icons.star_border_rounded),
      ('Promos', summary.promotions, Icons.campaign_outlined),
      ('Propiedades', summary.properties, Icons.home_work_outlined),
      ('Transporte', summary.transport, Icons.local_shipping_outlined),
      ('Menus', summary.menus, Icons.restaurant_menu_outlined),
      ('Ventas', summary.sales, Icons.payments_outlined),
    ];

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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(metric.$3, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 8),
                Text(metric.$1),
                Text(
                  '${metric.$2}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
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

class _ActionsGrid extends StatelessWidget {
  const _ActionsGrid({required this.summary});

  final BusinessDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final business = summary.business;
    final actions = _actionsForBusiness(business.businessParentCategory);

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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_BusinessAction> _actionsForBusiness(String? parentCategory) {
    final common = [
      ('Inventario', Icons.inventory_2_outlined, AppRoutes.businessInventory),
      ('Negocio', Icons.palette_outlined, AppRoutes.businessSettings),
      ('Promos', Icons.campaign_outlined, AppRoutes.businessPromotions),
      ('Pedidos', Icons.receipt_long_outlined, AppRoutes.businessOrders),
    ];

    final categorySpecific = switch (parentCategory) {
      'gastronomia' => [
        ('Menus QR', Icons.restaurant_menu_outlined, AppRoutes.businessMenus),
      ],
      'inmobiliaria' => [
        ('Propiedades', Icons.home_work_outlined, AppRoutes.businessProperties),
      ],
      'transporte' => [
        (
          'Transporte',
          Icons.local_shipping_outlined,
          AppRoutes.businessTransport,
        ),
      ],
      'servicio' => [
        ('Reservas', Icons.event_available_outlined, AppRoutes.businessOrders),
      ],
      _ => <(String, IconData, String)>[],
    };

    return [
      ...common,
      ...categorySpecific,
    ].map((item) => _BusinessAction(item.$1, item.$2, item.$3)).toList();
  }
}

class _BusinessAction {
  const _BusinessAction(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}
