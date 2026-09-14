import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/environment/app_environment.dart';

class ApkUpdateInfo {
  const ApkUpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.versionCode,
    this.releaseUrl,
    this.notes,
    this.publishedAt,
    required this.source,
  });

  final String version;
  final String downloadUrl;
  final int? versionCode;
  final String? releaseUrl;
  final String? notes;
  final DateTime? publishedAt;
  final String source;
}

class ApkUpdateStatus {
  const ApkUpdateStatus({
    required this.currentVersion,
    this.latest,
    required this.hasUpdate,
  });

  final String currentVersion;
  final ApkUpdateInfo? latest;
  final bool hasUpdate;
}

class ApkUpdateService {
  ApkUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<ApkUpdateInfo?> checkForUpdate() async {
    final status = await checkForUpdateStatus();
    if (!status.hasUpdate) return null;
    return status.latest;
  }

  Future<ApkUpdateStatus> checkForUpdateStatus() async {
    final current = await PackageInfo.fromPlatform();
    final response = await _dio.get<Map<String, dynamic>>(
      AppEnvironment.apkUpdateManifestUrl,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
      ),
    );

    final data = response.data;
    if (data == null) {
      return ApkUpdateStatus(
        currentVersion: _formatCurrentVersion(current),
        latest: null,
        hasUpdate: false,
      );
    }

    final version = _cleanVersion(
      '${data['version'] ?? data['tag_name'] ?? data['name'] ?? ''}',
    );
    final versionCode =
        _intOrNull(data['versionCode']) ??
        _intOrNull(data['version_code']) ??
        _splitBuild(version).item2;
    final downloadUrl =
        '${data['downloadUrl'] ?? data['browser_download_url'] ?? data['asset_url'] ?? ''}'
            .trim();
    if (version.isEmpty || downloadUrl.isEmpty) {
      return ApkUpdateStatus(
        currentVersion: _formatCurrentVersion(current),
        latest: null,
        hasUpdate: false,
      );
    }

    final latest = ApkUpdateInfo(
      version: _displayVersion(version, versionCode),
      downloadUrl: downloadUrl,
      versionCode: versionCode,
      releaseUrl: _stringOrNull(data['releaseUrl'] ?? data['html_url']),
      notes: _stringOrNull(data['notes'] ?? data['body']),
      publishedAt: DateTime.tryParse(_stringOrNull(data['publishedAt']) ?? ''),
      source: _stringOrNull(data['source']) ?? 'remote',
    );

    return ApkUpdateStatus(
      currentVersion: _formatCurrentVersion(current),
      latest: latest,
      hasUpdate: _isNewerVersion(
        currentVersion: current.version,
        currentBuildNumber: current.buildNumber,
        remoteVersion: version,
        remoteVersionCode: versionCode,
      ),
    );
  }

  bool _isNewerVersion({
    required String currentVersion,
    required String currentBuildNumber,
    required String remoteVersion,
    int? remoteVersionCode,
  }) {
    final currentParts = _semanticVersionParts(currentVersion);
    final remoteParts = _semanticVersionParts(remoteVersion);
    for (
      var i = 0;
      i < math.max(currentParts.length, remoteParts.length);
      i++
    ) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final remotePart = i < remoteParts.length ? remoteParts[i] : 0;
      if (remotePart > currentPart) return true;
      if (remotePart < currentPart) return false;
    }
    final remoteBuild = remoteVersionCode ?? _splitBuild(remoteVersion).item2;
    final currentBuild = int.tryParse(currentBuildNumber.trim());
    if (remoteBuild != null && currentBuild != null) {
      return remoteBuild > currentBuild;
    }
    return false;
  }

  List<int> _semanticVersionParts(String value) {
    final cleaned = _cleanVersion(value);
    final split = _splitBuild(cleaned);
    final versionPart = split.item1;
    return versionPart
        .split('.')
        .map((item) => int.tryParse(item) ?? 0)
        .toList();
  }

  String _cleanVersion(String value) {
    return value.trim().replaceFirst(
      RegExp(r'^(apk[-_]?|v)', caseSensitive: false),
      '',
    );
  }

  String _formatCurrentVersion(PackageInfo info) {
    final build = info.buildNumber.trim();
    if (build.isEmpty) return info.version;
    return '${info.version}+$build';
  }

  _BuildSplit _splitBuild(String value) {
    final cleaned = value.trim();
    final match = RegExp(r'^(.+?)[+-](\d+)$').firstMatch(cleaned);
    if (match == null) return _BuildSplit(cleaned, null);
    return _BuildSplit(match.group(1)!, int.tryParse(match.group(2)!));
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    final parsed = int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String _displayVersion(String version, int? versionCode) {
    final split = _splitBuild(version);
    final build = versionCode ?? split.item2;
    if (build == null) return split.item1;
    return '${split.item1}+$build';
  }

  String? _stringOrNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class _BuildSplit {
  const _BuildSplit(this.item1, this.item2);

  final String item1;
  final int? item2;
}
