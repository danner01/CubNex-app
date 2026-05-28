import 'package:equatable/equatable.dart';

import '../../entities/user_role.dart';

enum AppSessionStatus { loading, unauthenticated, guest, authenticated }

class AppSessionState extends Equatable {
  const AppSessionState({
    required this.status,
    required this.role,
    this.userId,
    this.email,
    this.onboardingSeen = false,
  });

  const AppSessionState.loading()
    : status = AppSessionStatus.loading,
      role = UserRole.guest,
      userId = null,
      email = null,
      onboardingSeen = false;

  const AppSessionState.unauthenticated({this.onboardingSeen = false})
    : status = AppSessionStatus.unauthenticated,
      role = UserRole.guest,
      userId = null,
      email = null;

  const AppSessionState.guest({this.onboardingSeen = true})
    : status = AppSessionStatus.guest,
      role = UserRole.guest,
      userId = null,
      email = null;

  final AppSessionStatus status;
  final UserRole role;
  final String? userId;
  final String? email;
  final bool onboardingSeen;

  bool get isBusiness =>
      role == UserRole.businessAdmin || role == UserRole.superadmin;

  @override
  List<Object?> get props => [status, role, userId, email, onboardingSeen];
}
