import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
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
    Map<String, dynamic>? deliveryProfile,
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
  static const _fcmSyncTimeout = Duration(seconds: 6);

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
    if (result.isSuccess && (result.data?.accessToken.isEmpty ?? true)) {
      return const ApiResult.failure(
        ApiFailure(
          code: 'EMAIL_CONFIRMATION_REQUIRED',
          message:
              'Cuenta creada. Revisa tu correo para confirmar el email antes de iniciar sesion.',
          statusCode: 201,
        ),
      );
    }
    unawaited(_syncFcmTokenSafely(result));
    return result;
  }

  @override
  Future<ApiResult<AuthSessionModel>> loginWithGoogle() async {
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } on PlatformException catch (error) {
      return ApiResult.failure(_googlePlatformFailure(error));
    } catch (error) {
      return ApiResult.failure(
        ApiFailure(
          code: 'GOOGLE_ERROR',
          message: 'No se pudo iniciar con Google: $error',
        ),
      );
    }

    if (googleUser == null) {
      return const ApiResult.failure(
        ApiFailure(
          code: 'GOOGLE_CANCELADO',
          message: 'Inicio con Google cancelado.',
        ),
      );
    }

    late final GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } on PlatformException catch (error) {
      return ApiResult.failure(_googlePlatformFailure(error));
    }

    if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
      return const ApiResult.failure(
        ApiFailure(
          code: 'GOOGLE_ID_TOKEN_FALTANTE',
          message:
              'Google no devolvio idToken. Revisa GOOGLE_WEB_CLIENT_ID y la configuracion OAuth/Firebase.',
        ),
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _firebaseAuth.signInWithCredential(credential);

    final result = await _apiClient.post<AuthSessionModel>(
      '/auth/login-google',
      data: {
        'id_token': googleAuth.idToken,
        'access_token': googleAuth.accessToken,
        'provider': 'google',
      },
      parser: (json) => AuthSessionModel.fromLoginJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );

    if (!result.isSuccess && result.error != null) {
      final backendMessage = result.error!.message.toLowerCase();
      if (backendMessage.contains('accounts.google.com') &&
          backendMessage.contains('not enabled')) {
        return const ApiResult.failure(
          ApiFailure(
            code: 'GOOGLE_PROVIDER_BACKEND_DISABLED',
            message:
                'Google no esta habilitado en Supabase Auth. Activalo en Supabase > Authentication > Providers > Google.',
          ),
        );
      }

      if (backendMessage.contains('google no esta habilitado') ||
          backendMessage.contains('proveedor google')) {
        return const ApiResult.failure(
          ApiFailure(
            code: 'GOOGLE_PROVIDER_BACKEND_DISABLED',
            message:
                'Google no esta habilitado en Supabase Auth. Activalo en Supabase > Authentication > Providers > Google.',
          ),
        );
      }

      if (backendMessage.contains('supabase auth respondio 400') ||
          backendMessage.contains('supabase auth respondió 400')) {
        return const ApiResult.failure(
          ApiFailure(
            code: 'GOOGLE_PROVIDER_BACKEND_BAD_REQUEST',
            message:
                'Google ya autentico en Firebase, pero Supabase aun rechaza la sesion. Revisa el Client ID completo en Supabase y redespliega el backend en Vercel.',
          ),
        );
      }
    }

    unawaited(_syncFcmTokenSafely(result));
    return result;
  }

  ApiFailure _googlePlatformFailure(PlatformException error) {
    if (error.code == 'sign_in_failed' &&
        '${error.message}'.contains('ApiException: 10')) {
      return const ApiFailure(
        code: 'GOOGLE_CONFIG_INVALIDA',
        message:
            'Google Sign-In no esta configurado para esta app. Registra el paquete com.cubnex.app y el SHA-1/SHA-256 en Firebase.',
      );
    }

    return ApiFailure(
      code: 'GOOGLE_${error.code.toUpperCase()}',
      message: error.message ?? 'No se pudo iniciar con Google.',
    );
  }

  @override
  Future<ApiResult<AuthSessionModel>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
    Map<String, dynamic>? deliveryProfile,
  }) async {
    final result = await _apiClient.post<AuthSessionModel>(
      '/auth/registro',
      data: {
        'nombre_completo': fullName,
        'email': email,
        'password': password,
        'telefono': phone,
        'rol': role,
        if (deliveryProfile != null) 'delivery_perfil': deliveryProfile,
      },
      parser: (json) => AuthSessionModel.fromLoginJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    unawaited(_syncFcmTokenSafely(result));
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
    var token = await _apiClient.readAccessToken();
    if (token == null || token.isEmpty) {
      if (await _apiClient.refreshSession(force: true)) {
        token = await _apiClient.readAccessToken();
      }
    }

    if (token == null || token.isEmpty) {
      return const ApiResult.failure(
        ApiFailure(code: 'SIN_TOKEN', message: 'No hay sesion local.'),
      );
    }

    final sessionToken = token;
    return _apiClient.get<AuthSessionModel>(
      '/usuarios/perfil',
      parser: (json) {
        final list = json is List ? json : const [];
        final profile = list.isNotEmpty
            ? Map<String, dynamic>.from(list.first as Map)
            : <String, dynamic>{};
        return AuthSessionModel.fromProfileJson(profile, sessionToken);
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

  Future<void> _syncFcmTokenSafely(ApiResult<AuthSessionModel> result) async {
    try {
      await _syncFcmToken(result).timeout(_fcmSyncTimeout);
    } catch (_) {
      // FCM sync is non-critical and must not block auth flow.
    }
  }
}
