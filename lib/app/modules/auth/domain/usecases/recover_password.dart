import '../../../../config/http/api_result.dart';
import '../repositories/auth_repository.dart';

class RecoverPassword {
  const RecoverPassword(this._repository);

  final AuthRepository _repository;

  Future<ApiResult<bool>> call({required String email}) {
    return _repository.recoverPassword(email: email);
  }
}
