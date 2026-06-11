import 'package:cubnex_app/app/common/blocs/app_session/app_session_cubit.dart';
import 'package:cubnex_app/app/config/http/api_client.dart';
import 'package:cubnex_app/app/config/http/api_result.dart';
import 'package:cubnex_app/app/config/routes/app_routes.dart';
import 'package:cubnex_app/app/modules/auth/domain/entities/auth_session.dart';
import 'package:cubnex_app/app/modules/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el boton Preferencias navega a la ruta correcta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final sessionCubit = AppSessionCubit(
      authRepository: _FakeAuthRepository(),
      apiClient: ApiClient(),
    );
    await sessionCubit.continueAsGuest();

    final router = GoRouter(
      initialLocation: '/test-profile',
      routes: [
        GoRoute(
          path: '/test-profile',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.preferences),
                child: const Text('Preferencias'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.preferences,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Preferencias Target')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(AppRoutes.preferences, '/preferences');
    expect(find.text('Preferencias'), findsOneWidget);

    await tester.tap(find.text('Preferencias'));
    await tester.pumpAndSettle();

    expect(find.text('Preferencias Target'), findsOneWidget);
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
    Map<String, dynamic>? deliveryProfile,
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
