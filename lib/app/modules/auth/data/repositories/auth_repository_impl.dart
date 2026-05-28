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
      await _apiClient.saveSession(
        accessToken: result.data!.accessToken,
        refreshToken: result.data!.refreshToken,
      );
      return ApiResult.success(result.data!);
    }
    return ApiResult.failure(result.error!);
  }

  @override
  Future<ApiResult<AuthSession>> loginWithGoogle() async {
    final result = await _remoteDataSource.loginWithGoogle();
    if (result.isSuccess && result.data != null) {
      await _apiClient.saveSession(
        accessToken: result.data!.accessToken,
        refreshToken: result.data!.refreshToken,
      );
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
  }) async {
    final result = await _remoteDataSource.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: role,
    );
    if (result.isSuccess && result.data != null) {
      await _apiClient.saveSession(
        accessToken: result.data!.accessToken,
        refreshToken: result.data!.refreshToken,
      );
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
}
