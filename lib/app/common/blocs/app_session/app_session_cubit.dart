import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/http/api_client.dart';
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
       super(const AppSessionState.loading());

  final AuthRepository _authRepository;
  final ApiClient _apiClient;
  static const _onboardingSeenKey = 'onboarding.seen';

  Future<void> restoreSession() async {
    await _apiClient.clearSession();
    emit(const AppSessionState.unauthenticated());
  }

  Future<void> setSession(AuthSession session) async {
    await _apiClient.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
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

}
