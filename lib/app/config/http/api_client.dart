import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 18),
              sendTimeout: const Duration(seconds: 12),
              headers: const {'accept': 'application/json'},
            ),
          ),
      _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.extra[_requestStartedAtExtra] =
              DateTime.now().millisecondsSinceEpoch;
          if (!_skipsAuthRefresh(options)) {
            await refreshSession(force: false);
          }

          final token = await _secureStorage.read(key: _accessTokenKey);
          if (token != null && token.isNotEmpty && !_skipsAuth(options)) {
            options.headers['authorization'] = 'Bearer $token';
          }
          _debugApi(
            '--> ${options.method} ${options.path}'
            '${options.queryParameters.isEmpty ? '' : ' query=${options.queryParameters}'}'
            '${options.data == null ? '' : ' body=${_safePayload(options.data)}'}',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          _debugApi(
            '<-- ${response.statusCode} ${response.requestOptions.method} '
            '${response.requestOptions.path} ${_elapsed(response.requestOptions)}ms '
            'data=${_safePayload(response.data)}',
          );
          handler.next(response);
        },
        onError: (error, handler) async {
          _debugApi(
            '<-- ERROR ${error.response?.statusCode ?? error.type.name} '
            '${error.requestOptions.method} ${error.requestOptions.path} '
            '${_elapsed(error.requestOptions)}ms '
            'data=${_safePayload(error.response?.data ?? error.message)}',
          );
          final requestOptions = error.requestOptions;
          final statusCode = error.response?.statusCode;
          final apiErrorCode = _extractApiErrorCode(error.response?.data);
          final hasAuthHeader = _hasAuthHeader(requestOptions.headers);
          final retryCount =
              (requestOptions.extra[_authRetryCountExtra] as int?) ?? 0;
          final canRefresh =
              statusCode == 401 &&
              !_skipsAuthRefresh(requestOptions) &&
              (!hasAuthHeader || _shouldTryRefresh(apiErrorCode));

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
              extra: {...requestOptions.extra, _skipAuthRefreshExtra: true},
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

          final canRetrySameToken =
              statusCode == 401 &&
              !_skipsAuthRefresh(requestOptions) &&
              hasAuthHeader &&
              apiErrorCode == 'SIN_TOKEN' &&
              retryCount < 1;

          if (canRetrySameToken) {
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
                _authRetryCountExtra: retryCount + 1,
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

          // Si una solicitud protegida termina en 401 despues de intentar la
          // renovacion, la sesion local ya no es util. Avisamos al estado
          // global para volver al login en lugar de dejar una vista cargando.
          if (statusCode == 401 &&
              hasAuthHeader &&
              !_skipsAuth(requestOptions)) {
            await _invalidateSession();
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
  static const _authRetryCountExtra = 'auth_retry_count';
  static const _requestStartedAtExtra = 'request_started_at';
  static const _refreshLeeway = Duration(minutes: 5);
  static const _defaultRequestTimeout = Duration(seconds: 22);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();
  Future<bool>? _refreshFuture;

  /// Se emite solo cuando una sesion autenticada ya no puede renovarse.
  /// Los cubits de presentacion la usan para volver al login sin dejar vistas
  /// protegidas con datos incompletos.
  Stream<void> get sessionExpired => _sessionExpiredController.stream;

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
        await _invalidateSession();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isTokenExpiringSoon() async {
    final expiresAtRaw = await _secureStorage.read(key: _tokenExpiresAtKey);
    final expiresAt = int.tryParse(expiresAtRaw ?? '');
    if (expiresAt == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - now <= _refreshLeeway.inSeconds;
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? parser,
    CancelToken? cancelToken,
    Duration timeout = _defaultRequestTimeout,
  }) {
    return _request<T>(
      () => _dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
      parser: parser,
      timeout: timeout,
    );
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? data,
    T Function(dynamic json)? parser,
    CancelToken? cancelToken,
    Duration timeout = _defaultRequestTimeout,
  }) {
    return _request<T>(
      () => _dio.post(path, data: data, cancelToken: cancelToken),
      parser: parser,
      timeout: timeout,
    );
  }

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? data,
    T Function(dynamic json)? parser,
    CancelToken? cancelToken,
    Duration timeout = _defaultRequestTimeout,
  }) {
    return _request<T>(
      () => _dio.put(path, data: data, cancelToken: cancelToken),
      parser: parser,
      timeout: timeout,
    );
  }

  Future<ApiResult<T>> delete<T>(
    String path, {
    Object? data,
    T Function(dynamic json)? parser,
    CancelToken? cancelToken,
    Duration timeout = _defaultRequestTimeout,
  }) {
    return _request<T>(
      () => _dio.delete(path, data: data, cancelToken: cancelToken),
      parser: parser,
      timeout: timeout,
    );
  }

  Future<ApiResult<T>> _request<T>(
    Future<Response<dynamic>> Function() request, {
    T Function(dynamic json)? parser,
    Duration timeout = _defaultRequestTimeout,
  }) async {
    try {
      final response = await request().timeout(timeout);
      final envelope = response.data;

      if (envelope is Map && envelope['exito'] == true) {
        final data = envelope['datos'];
        return ApiResult.success(parser == null ? data as T : parser(data));
      }

      // Log completo cuando el servidor no devuelve exito:true
      final rawEnvelope = _safePayload(envelope);
      debugPrint(
        '[API][NO_EXITO] status=${response.statusCode} '
        'path=${response.requestOptions.path} '
        'envelope=$rawEnvelope',
        wrapWidth: 2048,
      );

      final apiError = envelope is Map ? envelope['error'] as Map? : null;
      return ApiResult.failure(
        _normalizeFailure(
          code: '${apiError?['codigo'] ?? 'ERROR_API'}',
          message:
              '${apiError?['mensaje'] ?? 'Respuesta invalida del servidor'}',
          statusCode: response.statusCode,
        ),
      );
    } on TimeoutException catch (error) {
      debugPrint('[API][TIMEOUT] message=$error');
      return ApiResult.failure(
        ApiFailure(
          code: 'TIMEOUT',
          message:
              'La solicitud tardo demasiado. Intenta de nuevo; no dejamos la vista cargando.',
          statusCode: 408,
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      debugPrint(
        '[API][DIO_ERR] type=${error.type.name} '
        'status=${error.response?.statusCode} '
        'path=${error.requestOptions.path} '
        'message=${error.message} '
        'data=${_safePayload(data)}',
        wrapWidth: 2048,
      );
      final apiError = data is Map ? data['error'] as Map? : null;
      return ApiResult.failure(
        _normalizeFailure(
          code: '${apiError?['codigo'] ?? 'ERROR_RED'}',
          message: '${apiError?['mensaje'] ?? _friendlyNetworkMessage(error)}',
          statusCode: error.response?.statusCode,
          details: apiError?['detalles'] is Map
              ? Map<String, dynamic>.from(apiError?['detalles'] as Map)
              : null,
        ),
      );
    } catch (error) {
      debugPrint('[API][ERR] type=${error.runtimeType} message=$error');
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

    if (normalizedCode == 'SIN_TOKEN') {
      return ApiFailure(
        code: code,
        message:
            'No se pudo validar tu sesion en este momento. Intenta de nuevo en unos segundos.',
        statusCode: statusCode,
        details: details,
      );
    }

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
      case DioExceptionType.cancel:
        return 'Operacion cancelada.';
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

  Future<void> _invalidateSession() async {
    final hadSession = await hasLocalSession();
    await clearSession();
    if (hadSession && !_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  String? _extractApiErrorCode(Object? data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is! Map) return null;
    final code = error['codigo'];
    if (code == null) return null;
    return code.toString().toUpperCase();
  }

  bool _hasAuthHeader(Map<String, dynamic> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        final value = entry.value?.toString() ?? '';
        if (value.trim().isNotEmpty) return true;
      }
    }
    return false;
  }

  bool _shouldTryRefresh(String? apiErrorCode) {
    if (apiErrorCode == null || apiErrorCode.isEmpty) return true;
    if (apiErrorCode == 'SIN_TOKEN') return true;
    return true;
  }

  int _elapsed(RequestOptions options) {
    final startedAt = options.extra[_requestStartedAtExtra];
    if (startedAt is! int) return 0;
    return DateTime.now().millisecondsSinceEpoch - startedAt;
  }

  void _debugApi(String message) {
    debugPrint('[API] $message', wrapWidth: 1024);
  }

  String _safePayload(Object? value) {
    final sanitized = _sanitizePayload(value, depth: 0);
    final raw = sanitized.toString();
    if (raw.length <= 900) return raw;
    return '${raw.substring(0, 900)}...';
  }

  Object? _sanitizePayload(Object? value, {required int depth}) {
    if (depth >= 3) return '...';

    if (value is Map) {
      final result = <Object?, Object?>{};
      var index = 0;
      for (final entry in value.entries) {
        index++;
        if (index > 18) {
          result['...'] = '(${value.length} keys)';
          break;
        }
        final keyText = entry.key.toString().toLowerCase();
        if (keyText.contains('password') ||
            keyText.contains('token') ||
            keyText == 'authorization') {
          result[entry.key] = '***';
          continue;
        }
        result[entry.key] = _sanitizePayload(entry.value, depth: depth + 1);
      }
      return result;
    }

    if (value is List) {
      final maxItems = math.min(value.length, 5);
      final items = <Object?>[];
      for (var i = 0; i < maxItems; i++) {
        items.add(_sanitizePayload(value[i], depth: depth + 1));
      }
      if (value.length > maxItems) {
        items.add('...(${value.length} items)');
      }
      return items;
    }

    return value;
  }
}
