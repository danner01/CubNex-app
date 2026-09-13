import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/injection/injection.dart';
import '../../../orders/blocs/orders/orders_cubit.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../delivery_hub_section.dart';
import 'delivery_hub_dashboard_view.dart';
import 'delivery_hub_orders_view.dart';
import 'delivery_hub_profile_view.dart';
import 'delivery_route_screen.dart';

export '../delivery_hub_section.dart';

class DeliveryHubScreen extends StatelessWidget {
  const DeliveryHubScreen({required this.section, super.key});

  final DeliveryHubSection section;

  @override
  Widget build(BuildContext context) {
    if (section == DeliveryHubSection.dashboard) {
      return BlocProvider(
        create: (_) => sl<DeliveryCubit>()..load(),
        child: const DeliveryHubDashboardView(),
      );
    }
    if (section == DeliveryHubSection.requests ||
        section == DeliveryHubSection.history) {
      return BlocProvider(
        create: (_) => sl<OrdersCubit>()..load(),
        child: DeliveryHubOrdersView(section: section),
      );
    }
    if (section == DeliveryHubSection.route) {
      return const DeliveryRouteScreen();
    }
    return BlocProvider(
      create: (_) => sl<DeliveryCubit>()..load(),
      child: const DeliveryHubProfileView(),
    );
  }
}
