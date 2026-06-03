import '../../../../common/entities/user_role.dart';
import '../../domain/entities/auth_session.dart';

class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.accessToken,
    required super.userId,
    required super.role,
    super.refreshToken,
    super.expiresAt,
    super.expiresIn,
    super.email,
  });

  factory AuthSessionModel.fromLoginJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    final perfil = json['perfil'] is Map
        ? Map<String, dynamic>.from(json['perfil'] as Map)
        : <String, dynamic>{};

    return AuthSessionModel(
      accessToken: '${json['access_token'] ?? ''}',
      refreshToken: json['refresh_token']?.toString(),
      expiresAt: json['expires_at'] is num
          ? (json['expires_at'] as num).toInt()
          : null,
      expiresIn: json['expires_in'] is num
          ? (json['expires_in'] as num).toInt()
          : null,
      userId: '${user['id'] ?? ''}',
      email: user['email']?.toString(),
      role: UserRole.fromApi(perfil['rol']?.toString()),
    );
  }

  factory AuthSessionModel.fromProfileJson(
    Map<String, dynamic> json,
    String token,
  ) {
    return AuthSessionModel(
      accessToken: token,
      userId: '${json['id'] ?? ''}',
      email: json['email']?.toString(),
      role: UserRole.fromApi(json['rol']?.toString()),
    );
  }
}
