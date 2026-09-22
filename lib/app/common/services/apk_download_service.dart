import 'dart:io';

import 'package:apk_installer/apk_installer.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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

class ApkDownloadService {
  ApkDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  CancelToken? _cancelToken;

  Future<File?> downloadApk({
    required String url,
    void Function(ApkDownloadProgress)? onProgress,
  }) async {
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
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/octet-stream'},
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          expectedTotal = total;
          receivedTotal = received;
          onProgress?.call(ApkDownloadProgress(
            received: received,
            total: total,
            percent: (received / total * 100).clamp(0.0, 100.0),
          ));
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
  }

  bool get isDownloading => _cancelToken != null;

  Future<void> installApk(File apkFile) async {
    if (!await apkFile.exists()) {
      throw Exception('El archivo APK no existe.');
    }

    await ApkInstaller.installApk(filePath: apkFile.path);
  }
}
