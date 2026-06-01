import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'common/blocs/app_session/app_session_cubit.dart';
import 'common/blocs/app_theme/app_theme_cubit.dart';
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
        BlocProvider.value(value: sl<CartCubit>()),
      ],
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
    );
  }
}
