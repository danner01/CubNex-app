import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../config/injection/injection.dart';
import '../../services/apk_update_service.dart';
import 'update_download_sheet.dart';

class ApkVersionCard extends StatefulWidget {
  const ApkVersionCard({super.key});

  @override
  State<ApkVersionCard> createState() => _ApkVersionCardState();
}

class _ApkVersionCardState extends State<ApkVersionCard> {
  String? _installedVersion;
  bool _checkingUpdates = false;
  bool _hasUpdate = false;
  String? _latestVersion;

  @override
  void initState() {
    super.initState();
    _loadInstalledVersion();
  }

  Future<void> _loadInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    final value = build.isEmpty ? info.version : '${info.version}+$build';
    if (!mounted) return;
    setState(() => _installedVersion = value);
  }

  Future<void> _checkUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final status = await sl<ApkUpdateService>().checkForUpdateStatus();
      if (!mounted) return;
      setState(() {
        _hasUpdate = status.hasUpdate;
        _latestVersion = status.latest?.version;
      });
      await _showUpdateModal(status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo verificar actualizaciones: $error')),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _showUpdateModal(ApkUpdateStatus status) async {
    final latest = status.latest;

    if (!status.hasUpdate || latest == null) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Estado de la APK'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version instalada: ${status.currentVersion}'),
                const SizedBox(height: 8),
                Text(
                  'Tu APK ya esta actualizada.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => UpdateDownloadSheet(update: latest),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Version APK',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_hasUpdate) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Nueva: $_latestVersion',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _installedVersion == null
                  ? 'Cargando version instalada...'
                  : 'Instalada: $_installedVersion',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _checkingUpdates ? null : () => _checkUpdates(),
              icon: _checkingUpdates
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _hasUpdate
                          ? Icons.system_update_alt_rounded
                          : Icons.refresh_rounded,
                    ),
              label: Text(
                _hasUpdate ? 'Actualizar ahora' : 'Buscar actualizaciones',
              ),
            ),
          ],
        ),
      ),
    );
  }
}