import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../common/blocs/app_session/app_session_cubit.dart';
import '../../common/presentation/screens/onboarding_screen.dart';
import '../../common/presentation/screens/splash_screen.dart';
import '../../common/presentation/widgets/home_shell.dart';
import '../../modules/auth/presentation/screens/login_screen.dart';
import '../../modules/address/presentation/screens/map_screen.dart';
import '../../modules/business/presentation/screens/business_dashboard_screen.dart';
import '../../modules/business/presentation/screens/business_inventory_screen.dart';
import '../../modules/business/presentation/screens/business_settings_screen.dart';
import '../../modules/business_directory/presentation/screens/business_detail_screen.dart';
import '../../modules/favorites/presentation/screens/favorites_screen.dart';
import '../../modules/gamification/presentation/screens/gamification_screen.dart';
import '../../modules/home/presentation/screens/home_screen.dart';
import '../../modules/menus/presentation/screens/business_menus_screen.dart';
import '../../modules/notifications/presentation/screens/notifications_screen.dart';
import '../../modules/orders/presentation/screens/cart_screen.dart';
import '../../modules/orders/presentation/screens/business_orders_screen.dart';
import '../../modules/orders/presentation/screens/orders_screen.dart';
import '../../modules/product/presentation/screens/product_detail_screen.dart';
import '../../modules/posts/presentation/screens/posts_feed_screen.dart';
import '../../modules/profile/presentation/screens/profile_screen.dart';
import '../../modules/profile/presentation/screens/preferences_screen.dart';
import '../../modules/promotions/presentation/screens/promotions_screen.dart';
import '../../modules/properties/presentation/screens/properties_screen.dart';
import '../../modules/review_rating/presentation/screens/my_reviews_screen.dart';
import '../../modules/scanner/presentation/screens/scanner_screen.dart';
import '../../modules/scanner/presentation/screens/scan_history_screen.dart';
import '../../modules/search/presentation/screens/search_screen.dart';
import '../../modules/service/data/models/asset_detail_model.dart';
import '../../modules/service/presentation/screens/asset_detail_screen.dart';
import '../../modules/transport/presentation/screens/transport_screen.dart';
import '../../modules/wizard/presentation/screens/business_wizard_screen.dart';
import 'app_routes.dart';

GoRouter createAppRouter(AppSessionCubit sessionCubit) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(sessionCubit.stream),
    redirect: (context, state) {
      final session = sessionCubit.state;
      final isLogin = state.matchedLocation == AppRoutes.login;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (session.status == AppSessionStatus.loading) {
        return (isSplash || isLogin || isOnboarding) ? null : AppRoutes.splash;
      }

      if (session.status == AppSessionStatus.unauthenticated) {
        final target = session.onboardingSeen
            ? AppRoutes.login
            : AppRoutes.onboarding;
        return (isSplash || isLogin || isOnboarding) ? null : target;
      }

      if (session.status == AppSessionStatus.guest) {
        if (isSplash) return null;
        return (isLogin || isOnboarding) ? AppRoutes.home : null;
      }

      if (session.status == AppSessionStatus.authenticated) {
        if (isSplash) return null;
        if (!isLogin && !isOnboarding) return null;
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, __) => const SearchScreen(),
          ),
          GoRoute(
            path: AppRoutes.map,
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: AppRoutes.scanner,
            builder: (_, __) => const ScannerScreen(),
          ),
          GoRoute(
            path: AppRoutes.scanHistory,
            builder: (_, __) => const ScanHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.preferences,
            builder: (_, __) => const PreferencesScreen(),
          ),
          GoRoute(
            path: AppRoutes.gamification,
            builder: (_, __) => const GamificationScreen(),
          ),
          GoRoute(
            path: AppRoutes.promotions,
            builder: (_, __) => const PromotionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.posts,
            builder: (_, __) => const PostsFeedScreen(),
          ),
          GoRoute(
            path: AppRoutes.myReviews,
            builder: (_, __) => const MyReviewsScreen(),
          ),
          GoRoute(
            path: AppRoutes.properties,
            builder: (_, __) => const PropertiesScreen(),
          ),
          GoRoute(
            path: AppRoutes.propertyDetail,
            builder: (_, state) => AssetDetailScreen(
              assetId: state.pathParameters['id'] ?? '',
              kind: AssetDetailKind.property,
            ),
          ),
          GoRoute(
            path: AppRoutes.transport,
            builder: (_, __) => const TransportScreen(),
          ),
          GoRoute(
            path: AppRoutes.transportDetail,
            builder: (_, state) => AssetDetailScreen(
              assetId: state.pathParameters['id'] ?? '',
              kind: AssetDetailKind.transport,
            ),
          ),
          GoRoute(
            path: AppRoutes.favorites,
            builder: (_, __) => const FavoritesScreen(),
          ),
          GoRoute(
            path: AppRoutes.cart,
            builder: (_, __) => const CartScreen(),
          ),
          GoRoute(
            path: AppRoutes.orders,
            builder: (_, __) => const OrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.productDetail,
            builder: (_, state) => ProductDetailScreen(
              productId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: AppRoutes.businessDetail,
            builder: (_, state) => BusinessDetailScreen(
              businessId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: AppRoutes.businessDashboard,
            builder: (_, __) => const BusinessDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessPromotions,
            builder: (_, __) => const BusinessPromotionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessProperties,
            builder: (_, __) => const BusinessPropertiesScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessTransport,
            builder: (_, __) => const BusinessTransportScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessMenus,
            builder: (_, __) => const BusinessMenusScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessOrders,
            builder: (_, __) => const BusinessOrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessInventory,
            builder: (_, __) => const BusinessInventoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessSettings,
            builder: (_, __) => const BusinessSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessWizard,
            builder: (_, __) => const BusinessWizardScreen(),
          ),
        ],
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
