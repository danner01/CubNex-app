import '../../../../config/http/api_result.dart';
import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<ApiResult<AuthSession>> loginWithEmail({
    required String email,
    required String password,
  });

  Future<ApiResult<AuthSession>> loginWithGoogle();

  Future<ApiResult<AuthSession>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  });

  Future<ApiResult<bool>> recoverPassword({required String email});

  Future<ApiResult<AuthSession>> me();

  Future<void> logout();
}
