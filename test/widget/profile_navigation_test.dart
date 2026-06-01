import 'package:cubnex_app/app/common/blocs/app_session/app_session_cubit.dart';
import 'package:cubnex_app/app/config/http/api_client.dart';
import 'package:cubnex_app/app/config/http/api_result.dart';
import 'package:cubnex_app/app/config/routes/app_routes.dart';
import 'package:cubnex_app/app/modules/auth/domain/entities/auth_session.dart';
import 'package:cubnex_app/app/modules/auth/domain/repositories/auth_repository.dart';
import 'package:cubnex_app/app/modules/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el boton Preferencias navega a la ruta V2', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sessionCubit = AppSessionCubit(
      authRepository: _FakeAuthRepository(),
      apiClient: ApiClient(),
    );
    await sessionCubit.continueAsGuest();

    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => BlocProvider.value(
            value: sessionCubit,
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.preferences,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Preferencias V2 Target')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(AppRoutes.preferences, '/preferences-v2');
    await tester.scrollUntilVisible(
      find.text('Preferencias'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Preferencias'), findsOneWidget);

    await tester.tap(find.text('Preferencias'));
    await tester.pumpAndSettle();

    expect(find.text('Preferencias V2 Target'), findsOneWidget);
    await sessionCubit.close();
  });
}

class _FakeAuthRepository implements AuthRepository {
  static const _failure = ApiFailure(
    code: 'TEST',
    message: 'Repositorio falso para pruebas de navegacion.',
  );

  @override
  Future<ApiResult<AuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async => const ApiResult.failure(_failure);

  @override
  Future<ApiResult<AuthSession>> loginWithGoogle() async =>
      const ApiResult.failure(_failure);

  @override
  Future<ApiResult<AuthSession>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  }) async => const ApiResult.failure(_failure);

  @override
  Future<ApiResult<bool>> recoverPassword({required String email}) async =>
      const ApiResult.success(true);

  @override
  Future<ApiResult<AuthSession>> me() async =>
      const ApiResult.failure(_failure);

  @override
  Future<void> logout() async {}
}
