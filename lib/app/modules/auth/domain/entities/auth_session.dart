import '../../../../common/entities/user_role.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.role,
    this.refreshToken,
    this.email,
  });

  final String accessToken;
  final String? refreshToken;
  final String userId;
  final String? email;
  final UserRole role;
}
