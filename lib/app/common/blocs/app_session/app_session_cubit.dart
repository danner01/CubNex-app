import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/http/api_client.dart';
import '../../../config/http/api_result.dart';
import '../../../modules/auth/domain/entities/auth_session.dart';
import '../../../modules/auth/domain/repositories/auth_repository.dart';
import 'app_session_state.dart';

export 'app_session_state.dart';

class AppSessionCubit extends Cubit<AppSessionState> {
  AppSessionCubit({
    required AuthRepository authRepository,
    required ApiClient apiClient,
  }) : _authRepository = authRepository,
       _apiClient = apiClient,
       super(const AppSessionState.loading()) {
    _sessionExpiredSubscription = _apiClient.sessionExpired.listen((_) {
      unawaited(_handleExpiredSession());
    });
  }

  final AuthRepository _authRepository;
  final ApiClient _apiClient;
  late final StreamSubscription<void> _sessionExpiredSubscription;
  static const _onboardingSeenKey = 'onboarding.seen';
  static const _sessionSaveTimeout = Duration(seconds: 4);
  static const _restoreTimeout = Duration(seconds: 8);

  Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final onboardingSeen = preferences.getBool(_onboardingSeenKey) ?? false;

    Future<void> emitUnauthenticated() async {
      try {
        await _apiClient.clearSession();
      } catch (_) {}
      if (!isClosed) {
        emit(AppSessionState.unauthenticated(onboardingSeen: onboardingSeen));
      }
    }

    try {
      final hasSession = await _apiClient
          .hasLocalSession()
          .timeout(_restoreTimeout, onTimeout: () => false);
      if (!hasSession) {
        await emitUnauthenticated();
        return;
      }

      final result = await _authRepository
          .me()
          .timeout(
            _restoreTimeout,
            onTimeout: () => ApiResult.failure(
              const ApiFailure(code: 'timeout', message: 'Tiempo de espera agotado'),
            ),
          );
      if (result.isSuccess && result.data != null) {
        _emitAuthenticated(result.data!);
        return;
      }

      await emitUnauthenticated();
    } catch (_) {
      await emitUnauthenticated();
    }
  }

  Future<void> setSession(AuthSession session) async {
    await _apiClient
        .saveSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          expiresAt: session.expiresAt,
          expiresIn: session.expiresIn,
        )
        .timeout(_sessionSaveTimeout);
    _emitAuthenticated(session);
  }

  Future<void> logout() async {
    await _authRepository.logout();
    emit(const AppSessionState.unauthenticated());
  }

  Future<void> continueAsGuest() async {
    await markOnboardingSeen();
    emit(const AppSessionState.guest());
  }

  Future<void> markOnboardingSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingSeenKey, true);
    emit(const AppSessionState.unauthenticated(onboardingSeen: true));
  }

  void _emitAuthenticated(AuthSession session) {
    emit(
      AppSessionState(
        status: AppSessionStatus.authenticated,
        role: session.role,
        userId: session.userId,
        email: session.email,
        onboardingSeen: true,
      ),
    );
  }

  Future<void> _handleExpiredSession() async {
    final preferences = await SharedPreferences.getInstance();
    final onboardingSeen = preferences.getBool(_onboardingSeenKey) ?? true;
    if (!isClosed) {
      emit(AppSessionState.unauthenticated(onboardingSeen: onboardingSeen));
    }
  }

  @override
  Future<void> close() async {
    await _sessionExpiredSubscription.cancel();
    return super.close();
  }
}
