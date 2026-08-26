import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'common/blocs/app_session/app_session_cubit.dart';
import 'common/blocs/app_theme/app_theme_cubit.dart';
import 'common/blocs/active_business/active_business_cubit.dart';
import 'common/blocs/employee_access/employee_access_cubit.dart';
import 'common/blocs/role_mode/role_mode_cubit.dart';
import 'common/entities/user_role.dart';
import 'common/services/push_notification_service.dart';
import 'config/injection/injection.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'modules/credits/blocs/credits_cubit.dart';
import 'modules/orders/blocs/cart/cart_cubit.dart';

class ConKkaoApp extends StatelessWidget {
  const ConKkaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AppSessionCubit>()..restoreSession()),
        BlocProvider.value(value: sl<AppThemeCubit>()),
        BlocProvider.value(value: sl<RoleModeCubit>()),
        BlocProvider.value(value: sl<ActiveBusinessCubit>()),
        BlocProvider.value(value: sl<EmployeeAccessCubit>()),
        BlocProvider.value(value: sl<CartCubit>()..restore()),
                BlocProvider.value(value: sl<CreditsCubit>()),
              ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<AppSessionCubit, AppSessionState>(
            listenWhen: (previous, current) =>
                previous.status != current.status ||
                previous.role != current.role ||
                previous.userId != current.userId,
                      listener: (context, session) {
                        final roleMode = context.read<RoleModeCubit>();
                        final employeeAccess = context.read<EmployeeAccessCubit>();
                        final activeBusiness = context.read<ActiveBusinessCubit>();

                        if (session.status != AppSessionStatus.authenticated) {
                          roleMode.syncWithRole(session.role);
                          employeeAccess.clear();
                          activeBusiness.clear();
                          return;
                        }

                                                sl<CreditsCubit>().load();
                                                sl<PushNotificationService>().init();
                        // Fire-and-forget: EmployeeAccess listener refreshes RoleMode/ActiveBusiness.
                        employeeAccess.load().then((_) {
                          final access = employeeAccess.state;
                          final isBusinessOwner =
                              session.role == UserRole.businessAdmin ||
                              session.role == UserRole.superadmin;
                          roleMode.syncWithRole(
                            session.role,
                            hasEmployeeBusiness: access.hasActiveMembership,
                            hasEmployeeDelivery: access.hasDeliveryMembership,
                          );
                          if (isBusinessOwner || access.hasActiveMembership) {
                            activeBusiness.load();
                          } else {
                            activeBusiness.clear();
                          }
                        });
                      },
                    ),
          BlocListener<EmployeeAccessCubit, EmployeeAccessState>(
            listenWhen: (previous, current) =>
                previous.hasActiveMembership != current.hasActiveMembership ||
                previous.hasDeliveryMembership !=
                    current.hasDeliveryMembership ||
                previous.memberships.length != current.memberships.length,
            listener: (context, access) {
              final session = context.read<AppSessionCubit>().state;
              if (session.status != AppSessionStatus.authenticated) return;
              context.read<RoleModeCubit>().syncWithRole(
                session.role,
                hasEmployeeBusiness: access.hasActiveMembership,
                hasEmployeeDelivery: access.hasDeliveryMembership,
              );
              final isBusinessOwner =
                  session.role == UserRole.businessAdmin ||
                  session.role == UserRole.superadmin;
              if (isBusinessOwner || access.hasActiveMembership) {
                context.read<ActiveBusinessCubit>().load();
              }
            },
          ),
        ],
        child: Builder(
          builder: (context) {
            final router = createAppRouter(
              context.read<AppSessionCubit>(),
              context.read<RoleModeCubit>(),
            );

            return BlocBuilder<AppThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return MaterialApp.router(
                  title: 'ConKkao',
                  debugShowCheckedModeBanner: false,
                  scaffoldMessengerKey: PushNotificationService.messengerKey,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [Locale('es'), Locale('en')],
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: themeMode,
                  routerConfig: router,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
