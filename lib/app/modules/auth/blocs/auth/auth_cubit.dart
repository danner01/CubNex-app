import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/login_with_email.dart';
import '../../domain/usecases/login_with_google.dart';
import '../../domain/usecases/recover_password.dart';
import '../../domain/usecases/register_account.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required LoginWithEmail loginWithEmail,
    required LoginWithGoogle loginWithGoogle,
    required RegisterAccount registerAccount,
    required RecoverPassword recoverPassword,
  }) : _loginWithEmail = loginWithEmail,
       _loginWithGoogle = loginWithGoogle,
       _registerAccount = registerAccount,
       _recoverPassword = recoverPassword,
       super(const AuthState());

  final LoginWithEmail _loginWithEmail;
  final LoginWithGoogle _loginWithGoogle;
  final RegisterAccount _registerAccount;
  final RecoverPassword _recoverPassword;
  static const _requestTimeout = Duration(seconds: 40);

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    _debugAuth('login_email:start $email');
    try {
      final result = await _loginWithEmail(
        email: email,
        password: password,
      ).timeout(_requestTimeout);

      if (result.isSuccess && result.data != null) {
        _debugAuth('login_email:success role=${result.data!.role.name}');
        emit(state.copyWith(status: AuthStatus.success, session: result.data));
        return;
      }

      _debugAuth(
        'login_email:failure ${result.error?.code} ${result.error?.message}',
      );
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: result.error?.message ?? 'No se pudo iniciar sesion.',
        ),
      );
    } on TimeoutException {
      _debugAuth('login_email:timeout');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              'La autenticacion esta tardando demasiado. Verifica tu conexion e intenta de nuevo.',
        ),
      );
    } catch (error) {
      _debugAuth('login_email:unexpected $error');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'Ocurrio un error inesperado al iniciar sesion.',
        ),
      );
    }
  }

  void _debugAuth(String message) {
    if (kDebugMode) {
      debugPrint('[AUTH] $message');
    }
  }

  Future<void> loginWithGoogle() async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final result = await _loginWithGoogle().timeout(_requestTimeout);

      if (result.isSuccess && result.data != null) {
        emit(state.copyWith(status: AuthStatus.success, session: result.data));
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              result.error?.message ?? 'No se pudo iniciar con Google.',
        ),
      );
    } on TimeoutException {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              'Google Sign-In esta tardando demasiado. Intenta nuevamente en unos segundos.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'Ocurrio un error inesperado con Google Sign-In.',
        ),
      );
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final result = await _registerAccount(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        role: role,
      ).timeout(_requestTimeout);

      if (result.isSuccess && result.data != null) {
        emit(state.copyWith(status: AuthStatus.success, session: result.data));
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: result.error?.message ?? 'No se pudo crear la cuenta.',
        ),
      );
    } on TimeoutException {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              'El registro esta tardando demasiado. Revisa la conexion e intenta de nuevo.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'Ocurrio un error inesperado al crear la cuenta.',
        ),
      );
    }
  }

  Future<void> recoverPassword({required String email}) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final result = await _recoverPassword(
        email: email,
      ).timeout(_requestTimeout);

      if (result.isSuccess) {
        emit(
          state.copyWith(
            status: AuthStatus.recoverySent,
            errorMessage: 'Si el email existe, enviaremos un enlace.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: result.error?.message ?? 'No se pudo enviar el enlace.',
        ),
      );
    } on TimeoutException {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              'La recuperacion de acceso esta tardando demasiado. Intenta nuevamente.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'Ocurrio un error inesperado al recuperar acceso.',
        ),
      );
    }
  }
}
