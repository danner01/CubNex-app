import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/injection/injection.dart';
import '../../../orders/blocs/orders/orders_cubit.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../delivery_hub_section.dart';
import '../widgets/delivery_common.dart';
import 'delivery_hub_dashboard_view.dart';
import 'delivery_hub_orders_view.dart';
import 'delivery_hub_profile_view.dart';
import 'delivery_route_screen.dart';
import 'delivery_solicitudes_view.dart';

export '../delivery_hub_section.dart';

class DeliveryHubScreen extends StatelessWidget {
  const DeliveryHubScreen({required this.section, super.key});

  final DeliveryHubSection section;

  @override
  Widget build(BuildContext context) {
    if (section == DeliveryHubSection.dashboard) {
      return BlocProvider.value(
        value: sl<DeliveryCubit>(),
        child: const DeliveryCubitBootstrap(
          child: DeliveryHubDashboardView(),
        ),
      );
    }
    if (section == DeliveryHubSection.requests) {
      return BlocProvider.value(
        value: sl<DeliveryCubit>(),
        child: const DeliveryCubitBootstrap(
          child: DeliverySolicitudesView(),
        ),
      );
    }
    if (section == DeliveryHubSection.history) {
      return BlocProvider(
        create: (_) => sl<OrdersCubit>()..load(),
        child: DeliveryHubOrdersView(section: section),
      );
    }
    if (section == DeliveryHubSection.route) {
      return const DeliveryRouteScreen();
    }
    return BlocProvider.value(
      value: sl<DeliveryCubit>(),
      child: const DeliveryCubitBootstrap(
        child: DeliveryHubProfileView(),
      ),
    );
  }
}
