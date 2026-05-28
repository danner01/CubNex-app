import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/http/api_result.dart';
import '../models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<ApiResult<AuthSessionModel>> loginWithEmail({
    required String email,
    required String password,
  });

  Future<ApiResult<AuthSessionModel>> loginWithGoogle();

  Future<ApiResult<AuthSessionModel>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  });

  Future<ApiResult<bool>> recoverPassword({required String email});

  Future<ApiResult<AuthSessionModel>> me();

  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required ApiClient apiClient,
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FirebaseMessaging firebaseMessaging,
  }) : _apiClient = apiClient,
       _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn,
       _firebaseMessaging = firebaseMessaging;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseMessaging _firebaseMessaging;

  @override
  Future<ApiResult<AuthSessionModel>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _apiClient.post<AuthSessionModel>(
      '/auth/login',
      data: {'email': email, 'password': password},
      parser: (json) => AuthSessionModel.fromLoginJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    await _syncFcmToken(result);
    return result;
  }

  @override
  Future<ApiResult<AuthSessionModel>> loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return const ApiResult.failure(
        ApiFailure(
          code: 'GOOGLE_CANCELADO',
          message: 'Inicio con Google cancelado.',
        ),
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _firebaseAuth.signInWithCredential(credential);

    final result = await _apiClient.post<AuthSessionModel>(
      '/auth/login-google',
      data: {'id_token': googleAuth.idToken, 'provider': 'google'},
      parser: (json) => AuthSessionModel.fromLoginJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    await _syncFcmToken(result);
    return result;
  }

  @override
  Future<ApiResult<AuthSessionModel>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  }) async {
    final result = await _apiClient.post<AuthSessionModel>(
      '/auth/registro',
      data: {
        'nombre_completo': fullName,
        'email': email,
        'password': password,
        'telefono': phone,
        'rol': role,
      },
      parser: (json) => AuthSessionModel.fromLoginJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    await _syncFcmToken(result);
    return result;
  }

  @override
  Future<ApiResult<bool>> recoverPassword({required String email}) {
    return _apiClient.post<bool>(
      '/auth/recuperar-password',
      data: {'email': email},
      parser: (json) {
        if (json is Map) return json['enviado'] == true;
        return true;
      },
    );
  }

  @override
  Future<ApiResult<AuthSessionModel>> me() async {
    final token = await _apiClient.readAccessToken();
    if (token == null) {
      return const ApiResult.failure(
        ApiFailure(code: 'SIN_TOKEN', message: 'No hay sesion local.'),
      );
    }

    return _apiClient.get<AuthSessionModel>(
      '/usuarios/perfil',
      parser: (json) {
        final list = json is List ? json : const [];
        final profile = list.isNotEmpty
            ? Map<String, dynamic>.from(list.first as Map)
            : <String, dynamic>{};
        return AuthSessionModel.fromProfileJson(profile, token);
      },
    );
  }

  @override
  Future<void> logout() async {
    await _apiClient.post('/auth/logout');
    await _apiClient.clearSession();
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> _syncFcmToken(ApiResult<AuthSessionModel> result) async {
    if (!result.isSuccess) return;
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _apiClient.put('/auth/fcm-token', data: {'fcm_token': token});
    }
  }
}
