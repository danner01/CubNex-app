import '../../../../config/http/api_result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class RegisterAccount {
  const RegisterAccount(this._repository);

  final AuthRepository _repository;

  Future<ApiResult<AuthSession>> call({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
    Map<String, dynamic>? deliveryProfile,
  }) {
    return _repository.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: role,
      deliveryProfile: deliveryProfile,
    );
  }
}
