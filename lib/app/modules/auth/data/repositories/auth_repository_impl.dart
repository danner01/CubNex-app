import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required ApiClient apiClient,
  }) : _remoteDataSource = remoteDataSource,
       _apiClient = apiClient;

  final AuthRemoteDataSource _remoteDataSource;
  final ApiClient _apiClient;
  static const _sessionSaveTimeout = Duration(seconds: 4);

  @override
  Future<ApiResult<AuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _remoteDataSource.loginWithEmail(
      email: email,
      password: password,
    );
    if (result.isSuccess && result.data != null) {
      final sessionResult = await _saveSession(result.data!);
      if (sessionResult != null) return ApiResult.failure(sessionResult);
      return ApiResult.success(result.data!);
    }
    return ApiResult.failure(result.error!);
  }

  @override
  Future<ApiResult<AuthSession>> loginWithGoogle() async {
    final result = await _remoteDataSource.loginWithGoogle();
    if (result.isSuccess && result.data != null) {
      final sessionResult = await _saveSession(result.data!);
      if (sessionResult != null) return ApiResult.failure(sessionResult);
      return ApiResult.success(result.data!);
    }
    return ApiResult.failure(result.error!);
  }

  @override
  Future<ApiResult<AuthSession>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
    Map<String, dynamic>? deliveryProfile,
  }) async {
    final result = await _remoteDataSource.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: role,
      deliveryProfile: deliveryProfile,
    );
    if (result.isSuccess && result.data != null) {
      final sessionResult = await _saveSession(result.data!);
      if (sessionResult != null) return ApiResult.failure(sessionResult);
      return ApiResult.success(result.data!);
    }
    return ApiResult.failure(result.error!);
  }

  @override
  Future<ApiResult<bool>> recoverPassword({required String email}) {
    return _remoteDataSource.recoverPassword(email: email);
  }

  @override
  Future<ApiResult<AuthSession>> me() async {
    final result = await _remoteDataSource.me();
    if (result.isSuccess && result.data != null) {
      return ApiResult.success(result.data!);
    }
    return ApiResult.failure(result.error!);
  }

  @override
  Future<void> logout() => _remoteDataSource.logout();

  Future<ApiFailure?> _saveSession(AuthSession session) async {
    if (session.accessToken.trim().isEmpty) {
      return const ApiFailure(
        code: 'EMAIL_CONFIRMATION_REQUIRED',
        message:
            'Cuenta creada, pero falta confirmar el correo antes de iniciar sesion.',
      );
    }

    try {
      await _apiClient
          .saveSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: session.expiresAt,
            expiresIn: session.expiresIn,
          )
          .timeout(_sessionSaveTimeout);
      return null;
    } catch (_) {
      return const ApiFailure(
        code: 'SESSION_SAVE_FAILED',
        message:
            'La cuenta se creo, pero no se pudo guardar la sesion en este dispositivo. Intenta iniciar sesion.',
      );
    }
  }
}
