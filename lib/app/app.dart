import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'common/blocs/app_session/app_session_cubit.dart';
import 'common/blocs/app_theme/app_theme_cubit.dart';
import 'common/blocs/active_business/active_business_cubit.dart';
import 'common/blocs/role_mode/role_mode_cubit.dart';
import 'common/entities/user_role.dart';
import 'common/services/push_notification_service.dart';
import 'config/injection/injection.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'modules/orders/blocs/cart/cart_cubit.dart';

class CubNexApp extends StatelessWidget {
  const CubNexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AppSessionCubit>()..restoreSession()),
        BlocProvider.value(value: sl<AppThemeCubit>()),
        BlocProvider.value(value: sl<RoleModeCubit>()),
        BlocProvider.value(value: sl<ActiveBusinessCubit>()),
        BlocProvider.value(value: sl<CartCubit>()..restore()),
      ],
      child: BlocListener<AppSessionCubit, AppSessionState>(
        listenWhen: (previous, current) => previous.role != current.role,
        listener: (context, session) {
          context.read<RoleModeCubit>().syncWithRole(session.role);
          if (session.role == UserRole.businessAdmin ||
              session.role == UserRole.superadmin) {
            context.read<ActiveBusinessCubit>().load();
          } else {
            context.read<ActiveBusinessCubit>().clear();
          }
        },
        child: Builder(
          builder: (context) {
            final router = createAppRouter(context.read<AppSessionCubit>());

            return BlocBuilder<AppThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return MaterialApp.router(
                  title: 'CubNex',
                  debugShowCheckedModeBanner: false,
                  scaffoldMessengerKey: PushNotificationService.messengerKey,
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
