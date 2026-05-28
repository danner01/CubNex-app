import '../../../../config/http/api_result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class LoginWithGoogle {
  const LoginWithGoogle(this._repository);

  final AuthRepository _repository;

  Future<ApiResult<AuthSession>> call() => _repository.loginWithGoogle();
}
