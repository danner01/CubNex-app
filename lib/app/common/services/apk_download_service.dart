import 'dart:io';

import 'package:apk_installer/apk_installer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'apk_update_service.dart';

enum ApkDownloadPhase {
  idle,
  downloading,
  completed,
  installing,
  error,
  cancelled,
}

class ApkDownloadProgress {
  const ApkDownloadProgress({
    required this.received,
    required this.total,
    required this.percent,
  });

  final int received;
  final int total;
  final double percent;
}

class ApkDownloadService extends ChangeNotifier with WidgetsBindingObserver {
  ApkDownloadService({Dio? dio}) : _dio = dio ?? Dio() {
    WidgetsBinding.instance.addObserver(this);
  }

  final Dio _dio;
  CancelToken? _cancelToken;
  ApkUpdateInfo? _update;
  File? _file;
  ApkDownloadPhase _phase = ApkDownloadPhase.idle;
  ApkDownloadProgress _progress = const ApkDownloadProgress(
    received: 0,
    total: 0,
    percent: 0,
  );
  String? _error;
  var _pendingInstall = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  ApkUpdateInfo? get update => _update;
  File? get file => _file;
  ApkDownloadPhase get phase => _phase;
  ApkDownloadProgress get progress => _progress;
  String? get error => _error;
  bool get isDownloading => _phase == ApkDownloadPhase.downloading;
  bool get isBusy =>
      _phase == ApkDownloadPhase.downloading ||
      _phase == ApkDownloadPhase.installing;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed && _pendingInstall) {
      _pendingInstall = false;
      final file = _file;
      if (file != null) {
        installApk(file);
      }
    }
  }

  Future<void> start(ApkUpdateInfo update) async {
    if (kIsWeb) {
      throw Exception(
        'Las actualizaciones de la APK solo estan disponibles en la app movil.',
      );
    }

    if (isBusy && _update?.downloadUrl == update.downloadUrl) {
      return;
    }

    if (_phase == ApkDownloadPhase.completed &&
        _file != null &&
        _update?.downloadUrl == update.downloadUrl) {
      await installApk(_file!);
      return;
    }

    _update = update;
    _error = null;
    _file = null;
    _pendingInstall = false;
    _phase = ApkDownloadPhase.downloading;
    _progress = const ApkDownloadProgress(received: 0, total: 0, percent: 0);
    notifyListeners();

    try {
      final file = await _downloadApk(update.downloadUrl);
      if (_phase == ApkDownloadPhase.cancelled) return;
      if (file == null) {
        _phase = ApkDownloadPhase.error;
        _error = 'No se pudo descargar el archivo.';
        notifyListeners();
        return;
      }

      _file = file;
      _phase = ApkDownloadPhase.completed;
      _progress = ApkDownloadProgress(
        received: _progress.total,
        total: _progress.total,
        percent: 100,
      );
      notifyListeners();
      await installApk(file);
    } catch (e) {
      if (_phase == ApkDownloadPhase.cancelled) return;
      _phase = ApkDownloadPhase.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<File?> downloadApk({
    required String url,
    void Function(ApkDownloadProgress)? onProgress,
  }) async {
    await start(
      ApkUpdateInfo(
        version: 'actualizacion',
        downloadUrl: url,
        source: 'direct',
      ),
    );
    onProgress?.call(_progress);
    return _file;
  }

  Future<File?> _downloadApk(String url) async {
    _cancelToken = CancelToken();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/conkkao_update.apk');

    if (await file.exists()) {
      await file.delete();
    }

    var expectedTotal = 0;
    var receivedTotal = 0;

    await _dio.download(
      url,
      file.path,
      cancelToken: _cancelToken,
      options: Options(
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/octet-stream'},
      ),
      onReceiveProgress: (received, total) {
        if (_phase == ApkDownloadPhase.cancelled) return;
        if (total > 0) {
          expectedTotal = total;
          receivedTotal = received;
          _progress = ApkDownloadProgress(
            received: received,
            total: total,
            percent: (received / total * 100).clamp(0.0, 100.0),
          );
          notifyListeners();
        }
      },
    );

    _cancelToken = null;

    if (expectedTotal > 0 && receivedTotal < expectedTotal) {
      await file.delete();
      throw Exception(
        'Descarga incompleta: se recibieron $receivedTotal de $expectedTotal bytes. '
        'Revisa tu conexion e intentalo de nuevo.',
      );
    }

    if (!await _isValidApk(file, length: expectedTotal)) {
      await file.delete();
      throw Exception(
        'El archivo descargado esta corrupto. '
        'Fue eliminado; intentalo de nuevo.',
      );
    }

    return file;
  }

  Future<bool> _isValidApk(File file, {required int length}) async {
    try {
      if (!await file.exists()) return false;
      if (length > 0 && await file.length() != length) return false;
      final raf = await file.open();
      try {
        final header = await raf.read(4);
        return header.length == 4 &&
            header[0] == 0x50 &&
            header[1] == 0x4B &&
            header[2] == 0x03 &&
            header[3] == 0x04;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    _cancelToken = null;
    _pendingInstall = false;
    _phase = ApkDownloadPhase.cancelled;
    notifyListeners();
  }

  Future<void> installApk(File apkFile) async {
    if (kIsWeb) {
      throw Exception('La instalacion de APK no esta disponible en la web.');
    }

    if (!await apkFile.exists()) {
      throw Exception('El archivo APK no existe.');
    }

    if (_lifecycle != AppLifecycleState.resumed) {
      _pendingInstall = true;
      _file = apkFile;
      _phase = ApkDownloadPhase.completed;
      notifyListeners();
      return;
    }

    _phase = ApkDownloadPhase.installing;
    notifyListeners();

    try {
      await ApkInstaller.installApk(filePath: apkFile.path);
      _phase = ApkDownloadPhase.completed;
      _pendingInstall = false;
      notifyListeners();
    } catch (e) {
      if (_lifecycle != AppLifecycleState.resumed) {
        _pendingInstall = true;
        _file = apkFile;
        _phase = ApkDownloadPhase.completed;
        notifyListeners();
        return;
      }
      _phase = ApkDownloadPhase.error;
      _error =
          'Error al instalar: $e\nVe a Ajustes > Aplicaciones > '
          'Permitir apps desconocidas y habilita este permiso.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
