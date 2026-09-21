import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/blocs/app_session/app_session_cubit.dart';
import '../../common/blocs/app_theme/app_theme_cubit.dart';
import '../../common/blocs/active_business/active_business_cubit.dart';
import '../../common/blocs/employee_access/employee_access_cubit.dart';
import '../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../common/services/contact_service.dart';
import '../../common/services/credit_service.dart';
import '../../common/services/apk_update_service.dart';
import '../../common/services/apk_download_service.dart';
import '../../common/services/push_notification_service.dart';
import '../../common/services/share_service.dart';
import '../../modules/auth/data/datasources/auth_remote_data_source.dart';
import '../../modules/auth/data/repositories/auth_repository_impl.dart';
import '../../modules/auth/domain/repositories/auth_repository.dart';
import '../../modules/auth/domain/usecases/login_with_email.dart';
import '../../modules/auth/domain/usecases/login_with_google.dart';
import '../../modules/auth/domain/usecases/logout.dart';
import '../../modules/auth/domain/usecases/recover_password.dart';
import '../../modules/auth/domain/usecases/register_account.dart';
import '../../modules/address/blocs/map/map_cubit.dart';
import '../../modules/business/blocs/inventory/business_inventory_cubit.dart';
import '../../modules/business/blocs/dashboard/business_dashboard_cubit.dart';
import '../../modules/business/blocs/settings/business_settings_cubit.dart';
import '../../modules/business_directory/blocs/business_detail/business_detail_cubit.dart';
import '../../modules/favorites/blocs/engagement/engagement_cubit.dart';
import '../../modules/favorites/blocs/favorites/favorites_cubit.dart';
import '../../modules/gamification/blocs/gamification/gamification_cubit.dart';
import '../../modules/credits/blocs/credits_cubit.dart';
import '../../modules/delivery/blocs/delivery/delivery_accepted_store.dart';
import '../../modules/delivery/blocs/delivery/delivery_cubit.dart';
import '../../modules/home/blocs/home/home_cubit.dart';
import '../../modules/menus/blocs/menus/menus_cubit.dart';
import '../../modules/notifications/blocs/notifications/notifications_cubit.dart';
import '../../modules/support_tickets/blocs/support_tickets/support_tickets_cubit.dart';
import '../../modules/orders/blocs/cart/cart_cubit.dart';
import '../../modules/orders/blocs/orders/orders_cubit.dart';
import '../../modules/product/blocs/product_detail/product_detail_cubit.dart';
import '../../modules/posts/blocs/posts/posts_cubit.dart';
import '../../modules/properties/blocs/properties/properties_cubit.dart';
import '../../modules/profile/blocs/preferences/preferences_cubit.dart';
import '../../modules/promotions/blocs/promotions/promotions_cubit.dart';
import '../../modules/review_rating/blocs/my_reviews/my_reviews_cubit.dart';
import '../../modules/scanner/blocs/scan_history/scan_history_cubit.dart';
import '../../modules/scanner/blocs/scanner/scanner_cubit.dart';
import '../../modules/search/blocs/search/search_cubit.dart';
import '../../modules/service/blocs/asset_detail/asset_detail_cubit.dart';
import '../../modules/transport/blocs/transport/transport_cubit.dart';
import '../../modules/tutorials/blocs/tutorial_progress_store.dart';
import '../../modules/wizard/blocs/business_wizard/business_wizard_cubit.dart';
import '../environment/app_environment.dart';
import '../http/api_client.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  if (sl.isRegistered<SharedPreferences>()) {
    return;
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  sl
    ..registerLazySingleton<SharedPreferences>(() => sharedPreferences)
    ..registerLazySingleton(ApiClient.new)
    ..registerLazySingleton(ApkUpdateService.new)
    ..registerLazySingleton(ApkDownloadService.new)
    ..registerLazySingleton(ContactService.new)
    ..registerLazySingleton(() => ShareService(apiClient: sl()))
    ..registerLazySingleton(() => CreditService(apiClient: sl()))
    ..registerLazySingleton(() => FirebaseAuth.instance)
    ..registerLazySingleton(() => FirebaseMessaging.instance)
    ..registerLazySingleton(
      () => PushNotificationService(firebaseMessaging: sl(), apiClient: sl()),
    )
    ..registerLazySingleton(
      () => AppEnvironment.googleWebClientId.isEmpty
          ? GoogleSignIn()
          : GoogleSignIn(serverClientId: AppEnvironment.googleWebClientId),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(
        apiClient: sl(),
        firebaseAuth: sl(),
        googleSignIn: sl(),
        firebaseMessaging: sl(),
      ),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: sl(), apiClient: sl()),
    )
    ..registerLazySingleton(() => LoginWithEmail(sl()))
    ..registerLazySingleton(() => LoginWithGoogle(sl()))
    ..registerLazySingleton(() => RegisterAccount(sl()))
    ..registerLazySingleton(() => RecoverPassword(sl()))
    ..registerLazySingleton(() => Logout(sl()))
    ..registerLazySingleton(
      () => AppSessionCubit(authRepository: sl(), apiClient: sl()),
    )
    ..registerLazySingleton(
      () => AppThemeCubit(sharedPreferences: sl())..load(),
    )
    ..registerLazySingleton(() => RoleModeCubit(sharedPreferences: sl()))
    ..registerLazySingleton(
      () => ActiveBusinessCubit(apiClient: sl(), sharedPreferences: sl()),
    )
    ..registerLazySingleton(() => EmployeeAccessCubit(apiClient: sl()))
    ..registerFactory(() => MapCubit(apiClient: sl()))
    ..registerFactory(() => HomeCubit(apiClient: sl()))
    ..registerFactory(() => MenusCubit(apiClient: sl()))
    ..registerFactory(
      () => NotificationsCubit(apiClient: sl(), pushNotificationService: sl()),
    )
    ..registerFactory(() => SupportTicketsCubit(apiClient: sl()))
    ..registerFactory(() => SearchCubit(apiClient: sl()))
    ..registerFactory(() => ProductDetailCubit(apiClient: sl()))
    ..registerFactory(() => PostsCubit(apiClient: sl()))
    ..registerFactory(() => AssetDetailCubit(apiClient: sl()))
    ..registerFactory(
      () => PreferencesCubit(apiClient: sl(), sharedPreferences: sl()),
    )
    ..registerFactory(() => PromotionsCubit(apiClient: sl()))
    ..registerFactory(() => PropertiesCubit(apiClient: sl()))
    ..registerFactory(() => TransportCubit(apiClient: sl()))
    ..registerFactory(() => MyReviewsCubit(apiClient: sl()))
    ..registerFactory(() => BusinessDetailCubit(apiClient: sl()))
    ..registerFactory(() => EngagementCubit(apiClient: sl()))
    ..registerFactory(() => FavoritesCubit(apiClient: sl()))
    ..registerFactory(() => GamificationCubit(apiClient: sl()))
    ..registerLazySingleton(() => CreditsCubit(apiClient: sl()))
    ..registerLazySingleton(
      () =>
          CartCubit(apiClient: sl(), cartBox: Hive.box<dynamic>('cart_items')),
    )
    ..registerFactory(() => OrdersCubit(apiClient: sl()))
    ..registerLazySingleton(() => DeliveryAcceptedStore())
    ..registerFactory(() => DeliveryCubit(apiClient: sl(), acceptedStore: sl()))
    ..registerLazySingleton(
      () => TutorialProgressStore(sharedPreferences: sl()),
    )
    ..registerFactory(() => ScannerCubit(apiClient: sl()))
    ..registerFactory(() => ScanHistoryCubit(apiClient: sl()))
    ..registerFactory(() => BusinessDashboardCubit(apiClient: sl()))
    ..registerFactory(() => BusinessInventoryCubit(apiClient: sl()))
    ..registerFactory(() => BusinessSettingsCubit(apiClient: sl()))
    ..registerFactory(() => BusinessWizardCubit(apiClient: sl()));
}
