import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../environment/app_environment.dart';
import 'api_result.dart';

class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? secureStorage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: '${AppEnvironment.apiBaseUrl}/api/v1',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
              headers: const {'accept': 'application/json'},
            ),
          ),
      _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: _accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<String?> readAccessToken() {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(
      () => _dio.get(path, queryParameters: queryParameters),
      parser: parser,
    );
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? data,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(() => _dio.post(path, data: data), parser: parser);
  }

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? data,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(() => _dio.put(path, data: data), parser: parser);
  }

  Future<ApiResult<T>> delete<T>(
    String path, {
    Object? data,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(() => _dio.delete(path, data: data), parser: parser);
  }

  Future<ApiResult<T>> _request<T>(
    Future<Response<dynamic>> Function() request, {
    T Function(dynamic json)? parser,
  }) async {
    try {
      final response = await request();
      final envelope = response.data;

      if (envelope is Map && envelope['exito'] == true) {
        final data = envelope['datos'];
        return ApiResult.success(parser == null ? data as T : parser(data));
      }

      final apiError = envelope is Map ? envelope['error'] as Map? : null;
      return ApiResult.failure(
        _normalizeFailure(
          code: '${apiError?['codigo'] ?? 'ERROR_API'}',
          message:
              '${apiError?['mensaje'] ?? 'Respuesta invalida del servidor'}',
          statusCode: response.statusCode,
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final apiError = data is Map ? data['error'] as Map? : null;
      return ApiResult.failure(
        _normalizeFailure(
          code: '${apiError?['codigo'] ?? 'ERROR_RED'}',
          message:
              '${apiError?['mensaje'] ?? _friendlyNetworkMessage(error)}',
          statusCode: error.response?.statusCode,
          details: apiError?['detalles'] is Map
              ? Map<String, dynamic>.from(apiError?['detalles'] as Map)
              : null,
        ),
      );
    } catch (error) {
      return ApiResult.failure(
        ApiFailure(code: 'ERROR_DESCONOCIDO', message: error.toString()),
      );
    }
  }

  ApiFailure _normalizeFailure({
    required String code,
    required String message,
    int? statusCode,
    Map<String, dynamic>? details,
  }) {
    final normalizedCode = code.toUpperCase();

    if (normalizedCode == 'CREDENCIALES_INVALIDAS' ||
        normalizedCode == 'EMAIL_NO_CONFIRMADO' ||
        normalizedCode == 'EMAIL_INVALIDO' ||
        normalizedCode == 'PASSWORD_DEBIL' ||
        normalizedCode == 'REGISTRO_INVALIDO' ||
        normalizedCode == 'USUARIO_YA_EXISTE') {
      return ApiFailure(
        code: code,
        message: message,
        statusCode: statusCode,
        details: details,
      );
    }

    final text = '$code $message'.toLowerCase();
    final isAuthRequired =
        statusCode == 401 ||
        text.contains('sin_token') ||
        text.contains('token bearer') ||
        text.contains('bearer') ||
        text.contains('sesion requerida') ||
        text.contains('sesión requerida') ||
        text.contains('no hay sesion') ||
        text.contains('no hay sesión') ||
        text.contains('unauthorized') ||
        text.contains('no autorizado');

    if (isAuthRequired) {
      return ApiFailure(
        code: 'AUTH_REQUIRED',
        message: 'Debes registrarte para acceder.',
        statusCode: statusCode ?? 401,
        details: details,
      );
    }

    return ApiFailure(
      code: code,
      message: message,
      statusCode: statusCode,
      details: details,
    );
  }

  String _friendlyNetworkMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'La conexion esta lenta. Mostramos contenido base mientras vuelve el servidor.';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor. Revisa internet o intenta de nuevo.';
      default:
        return error.message ?? 'Error de conexion';
    }
  }
}
