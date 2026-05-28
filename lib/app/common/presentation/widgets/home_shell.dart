import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes/app_routes.dart';
import 'market_app_bar.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: const MarketAppBar(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFromLocation(location),
        onDestinationSelected: (index) => context.go(_locationFromIndex(index)),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Escanear',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_center_outlined),
            selectedIcon: Icon(Icons.business_center),
            label: 'Negocio',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  int _indexFromLocation(String location) {
    if (location.startsWith(AppRoutes.search)) return 1;
    if (location.startsWith(AppRoutes.scanner)) return 2;
    if (location.startsWith('/business')) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  String _locationFromIndex(int index) {
    return switch (index) {
      1 => AppRoutes.search,
      2 => AppRoutes.scanner,
      3 => AppRoutes.businessDashboard,
      4 => AppRoutes.profile,
      _ => AppRoutes.home,
    };
  }
}
