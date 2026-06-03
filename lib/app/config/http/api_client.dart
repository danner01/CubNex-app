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
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_skipsAuthRefresh(options)) {
            await refreshSession(force: false);
          }

          final token = await _secureStorage.read(key: _accessTokenKey);
          if (token != null && token.isNotEmpty && !_skipsAuth(options)) {
            options.headers['authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final requestOptions = error.requestOptions;
          final canRefresh =
              error.response?.statusCode == 401 &&
              !_skipsAuthRefresh(requestOptions);

          if (canRefresh && await refreshSession(force: true)) {
            final token = await _secureStorage.read(key: _accessTokenKey);
            final retryOptions = Options(
              method: requestOptions.method,
              headers: {
                ...requestOptions.headers,
                if (token != null && token.isNotEmpty)
                  'authorization': 'Bearer $token',
              },
              responseType: requestOptions.responseType,
              contentType: requestOptions.contentType,
              extra: {
                ...requestOptions.extra,
                _skipAuthRefreshExtra: true,
              },
            );

            try {
              final response = await _dio.request<dynamic>(
                requestOptions.path,
                data: requestOptions.data,
                queryParameters: requestOptions.queryParameters,
                options: retryOptions,
                cancelToken: requestOptions.cancelToken,
                onReceiveProgress: requestOptions.onReceiveProgress,
                onSendProgress: requestOptions.onSendProgress,
              );
              handler.resolve(response);
              return;
            } on DioException catch (retryError) {
              handler.next(retryError);
              return;
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _tokenExpiresAtKey = 'auth.expires_at';
  static const _skipAuthRefreshExtra = 'skip_auth_refresh';
  static const _refreshLeeway = Duration(minutes: 5);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  Future<bool>? _refreshFuture;

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    int? expiresAt,
    int? expiresIn,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }

    final resolvedExpiresAt =
        expiresAt ??
        (expiresIn == null
            ? null
            : DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn);
    if (resolvedExpiresAt != null) {
      await _secureStorage.write(
        key: _tokenExpiresAtKey,
        value: resolvedExpiresAt.toString(),
      );
    }
  }

  Future<String?> readAccessToken() {
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<bool> hasLocalSession() async {
    final accessToken = await readAccessToken();
    final refreshToken = await readRefreshToken();
    return (accessToken != null && accessToken.isNotEmpty) ||
        (refreshToken != null && refreshToken.isNotEmpty);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenExpiresAtKey);
  }

  Future<bool> refreshSession({bool force = false}) {
    if (_refreshFuture != null) return _refreshFuture!;
    _refreshFuture = _refreshSession(force: force).whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<bool> _refreshSession({required bool force}) async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    if (!force && !await _isTokenExpiringSoon()) {
      return true;
    }

    try {
      final response = await _dio.post<dynamic>(
        '/auth/refresh-token',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {_skipAuthRefreshExtra: true}),
      );
      final envelope = response.data;
      final data = envelope is Map ? envelope['datos'] : null;
      if (data is! Map || data['access_token'] == null) {
        return false;
      }

      await saveSession(
        accessToken: '${data['access_token']}',
        refreshToken: data['refresh_token']?.toString(),
        expiresAt: data['expires_at'] is num
            ? (data['expires_at'] as num).toInt()
            : null,
        expiresIn: data['expires_in'] is num
            ? (data['expires_in'] as num).toInt()
            : null,
      );
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await clearSession();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isTokenExpiringSoon() async {
    final expiresAtRaw = await _secureStorage.read(key: _tokenExpiresAtKey);
    final expiresAt = int.tryParse(expiresAtRaw ?? '');
    if (expiresAt == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - now <= _refreshLeeway.inSeconds;
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

  bool _skipsAuth(RequestOptions options) {
    final path = options.path;
    return path.contains('/auth/login') ||
        path.contains('/auth/registro') ||
        path.contains('/auth/recuperar-password') ||
        path.contains('/auth/refresh-token');
  }

  bool _skipsAuthRefresh(RequestOptions options) {
    return options.extra[_skipAuthRefreshExtra] == true || _skipsAuth(options);
  }
}
