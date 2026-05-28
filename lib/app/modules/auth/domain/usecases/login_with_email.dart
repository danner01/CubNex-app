import '../../../../config/http/api_result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class LoginWithEmail {
  const LoginWithEmail(this._repository);

  final AuthRepository _repository;

  Future<ApiResult<AuthSession>> call({
    required String email,
    required String password,
  }) {
    return _repository.loginWithEmail(email: email, password: password);
  }
}
