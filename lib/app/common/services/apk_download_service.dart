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

    await _dio.download(
      url,
      file.path,
      cancelToken: _cancelToken,
      options: Options(
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/octet-stream'},
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(ApkDownloadProgress(
            received: received,
            total: total,
            percent: (received / total * 100).clamp(0.0, 100.0),
          ));
        }
      },
    );

    _cancelToken = null;
    return file;
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
