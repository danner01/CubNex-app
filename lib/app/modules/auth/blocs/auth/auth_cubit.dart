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

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _loginWithEmail(email: email, password: password);

    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(status: AuthStatus.success, session: result.data));
      return;
    }

    emit(
      state.copyWith(
        status: AuthStatus.failure,
        errorMessage: result.error?.message ?? 'No se pudo iniciar sesion.',
      ),
    );
  }

  Future<void> loginWithGoogle() async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _loginWithGoogle();

    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(status: AuthStatus.success, session: result.data));
      return;
    }

    emit(
      state.copyWith(
        status: AuthStatus.failure,
        errorMessage: result.error?.message ?? 'No se pudo iniciar con Google.',
      ),
    );
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _registerAccount(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: role,
    );

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
  }

  Future<void> recoverPassword({required String email}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _recoverPassword(email: email);

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
        errorMessage:
            result.error?.message ?? 'No se pudo enviar el enlace.',
      ),
    );
  }
}
