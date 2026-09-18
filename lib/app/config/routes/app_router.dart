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
import '../../modules/business/presentation/screens/business_store_preview_screen.dart';
import '../../modules/business/presentation/screens/business_team_screen.dart';
import '../../modules/business_directory/presentation/screens/business_detail_screen.dart';
import '../../modules/business_network/presentation/screens/business_network_screen.dart';
import '../../modules/delivery/presentation/screens/delivery_hub_screen.dart';
import '../../modules/delivery/presentation/screens/delivery_nearby_screen.dart';
import '../../modules/favorites/presentation/screens/favorites_screen.dart';
import '../../modules/credits/presentation/screens/credits_screen.dart';
import '../../modules/gamification/presentation/screens/gamification_screen.dart';
import '../../modules/home/presentation/screens/home_screen.dart';
import '../../modules/jobs/presentation/screens/business_jobs_screen.dart';
import '../../modules/jobs/presentation/screens/jobs_screen.dart';
import '../../modules/menus/presentation/screens/business_menus_screen.dart';
import '../../modules/notifications/presentation/screens/notifications_screen.dart';
import '../../modules/orders/presentation/screens/cart_screen.dart';
import '../../modules/orders/presentation/screens/business_orders_screen.dart';
import '../../modules/orders/presentation/screens/orders_screen.dart';
import '../../modules/product/presentation/screens/product_detail_screen.dart';
import '../../modules/posts/presentation/screens/posts_feed_screen.dart';
import '../../modules/posts/presentation/screens/business_posts_screen.dart';
import '../../modules/business/presentation/screens/business_plans_screen.dart';
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
import '../../modules/support_tickets/presentation/screens/support_tickets_screen.dart';
import '../../modules/transport/presentation/screens/transport_screen.dart';
import '../../modules/wizard/presentation/screens/business_wizard_screen.dart';
import 'app_routes.dart';
import '../../common/blocs/role_mode/role_mode_cubit.dart';

GoRouter createAppRouter(
  AppSessionCubit sessionCubit,
  RoleModeCubit roleModeCubit,
) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStreams([
      sessionCubit.stream,
      roleModeCubit.stream,
    ]),
    redirect: (context, state) {
      final session = sessionCubit.state;
      final activeMode = roleModeCubit.state.activeMode;
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
        final defaultLocation = _defaultLocationForMode(activeMode);
        final shouldUseRoleHome =
            isLogin ||
            isOnboarding ||
            (state.matchedLocation == AppRoutes.home &&
                activeMode != RoleMode.client);
        return shouldUseRoleHome ? defaultLocation : null;
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
      GoRoute(
        path: '/market/negocio/pedidos',
        redirect: (_, __) => AppRoutes.businessOrders,
      ),
      GoRoute(
        path: '/market/negocio/red',
        redirect: (_, __) => AppRoutes.businessNetwork,
      ),
      GoRoute(
        path: '/market/notificaciones',
        redirect: (_, __) => AppRoutes.notifications,
      ),
      GoRoute(
        path: '/market/negocios/:id',
        redirect: (_, state) =>
            AppRoutes.store(state.pathParameters['id'] ?? ''),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, __) => const SearchScreen(),
          ),
          GoRoute(path: AppRoutes.map, builder: (_, __) => const MapScreen()),
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
          GoRoute(path: AppRoutes.jobs, builder: (_, __) => const JobsScreen()),
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
          GoRoute(path: AppRoutes.cart, builder: (_, __) => const CartScreen()),
          GoRoute(
            path: AppRoutes.orders,
            builder: (_, __) => const OrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.credits,
            builder: (_, state) => CreditsScreen(
              initialAlias: state.uri.queryParameters['alias'],
              initialUserId:
                  state.uri.queryParameters['uid'] ??
                  state.uri.queryParameters['user_id'],
              initialQrPayload: state.uri.queryParameters['qr'],
            ),
          ),
          GoRoute(
            path: AppRoutes.billetera,
            builder: (_, state) => CreditsScreen(
              initialAlias: state.uri.queryParameters['alias'],
              initialUserId:
                  state.uri.queryParameters['uid'] ??
                  state.uri.queryParameters['user_id'],
              initialQrPayload: state.uri.queryParameters['qr'],
            ),
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
            path: AppRoutes.businessPosts,
            builder: (_, __) => const BusinessPostsScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessPlans,
            builder: (_, __) => const BusinessPlansScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessNetwork,
            builder: (_, __) => const BusinessNetworkScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessJobs,
            builder: (_, __) => const BusinessJobsScreen(),
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
            path: AppRoutes.businessMyOrders,
            builder: (_, __) => const OrdersScreen(businessRequesterView: true),
          ),
          GoRoute(
            path: AppRoutes.businessInventory,
            builder: (_, __) => const BusinessInventoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessStore,
            builder: (_, __) => const BusinessStorePreviewScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessSettings,
            builder: (_, __) => const BusinessSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessWizard,
            builder: (_, __) => const BusinessWizardScreen(),
          ),
          GoRoute(
            path: AppRoutes.businessTeam,
            builder: (_, __) => const BusinessTeamScreen(),
          ),
          GoRoute(
            path: AppRoutes.deliveryDashboard,
            builder: (_, __) =>
                const DeliveryHubScreen(section: DeliveryHubSection.dashboard),
          ),
          GoRoute(
            path: AppRoutes.deliveryRequests,
            builder: (_, __) =>
                const DeliveryHubScreen(section: DeliveryHubSection.requests),
          ),
          GoRoute(
            path: AppRoutes.deliveryRoute,
            builder: (_, __) =>
                const DeliveryHubScreen(section: DeliveryHubSection.route),
          ),
          GoRoute(
            path: AppRoutes.deliveryHistory,
            builder: (_, __) =>
                const DeliveryHubScreen(section: DeliveryHubSection.history),
          ),
          GoRoute(
            path: AppRoutes.deliveryProfile,
            builder: (_, __) =>
                const DeliveryHubScreen(section: DeliveryHubSection.profile),
          ),
          GoRoute(
            path: AppRoutes.deliveryNearby,
            builder: (_, __) => const DeliveryNearbyScreen(),
          ),
          GoRoute(
            path: AppRoutes.supportTickets,
            builder: (_, __) => const SupportTicketsScreen(),
          ),
        ],
      ),
    ],
  );
}

String _defaultLocationForMode(RoleMode mode) {
  return switch (mode) {
    RoleMode.business => AppRoutes.businessDashboard,
    RoleMode.delivery => AppRoutes.deliveryDashboard,
    RoleMode.client => AppRoutes.home,
  };
}

class GoRouterRefreshStreams extends ChangeNotifier {
  GoRouterRefreshStreams(List<Stream<dynamic>> streams) {
    notifyListeners();
    _subscriptions = streams
        .map(
          (stream) =>
              stream.asBroadcastStream().listen((_) => notifyListeners()),
        )
        .toList();
  }

  late final List<StreamSubscription<dynamic>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
