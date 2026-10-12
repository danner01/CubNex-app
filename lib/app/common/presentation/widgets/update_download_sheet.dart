import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../config/injection/injection.dart';
import '../../services/apk_download_service.dart';
import '../../services/apk_update_service.dart';

class UpdateDownloadSheet extends StatefulWidget {
  const UpdateDownloadSheet({required this.update, super.key});

  final ApkUpdateInfo update;

  @override
  State<UpdateDownloadSheet> createState() => _UpdateDownloadSheetState();
}

class _UpdateDownloadSheetState extends State<UpdateDownloadSheet> {
  late final ApkDownloadService _service;
  String? _installedVersion;

  @override
  void initState() {
    super.initState();
    _service = sl<ApkDownloadService>();
    _service.addListener(_onChanged);
    _loadInstalledVersion();
    _service.start(widget.update);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    final value = build.isEmpty ? info.version : '${info.version}+$build';
    if (!mounted) return;
    setState(() => _installedVersion = value);
  }

  void _hide() {
    Navigator.of(context).pop();
  }

  void _cancel() {
    _service.cancelDownload();
    Navigator.of(context).pop();
  }

  Future<void> _retry() async {
    await _service.start(widget.update);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final phase = _service.phase;
    final downloading = phase == ApkDownloadPhase.downloading;
    final installing = phase == ApkDownloadPhase.installing;
    final completed =
        phase == ApkDownloadPhase.completed || installing;
    final error = _service.error;
    final progress = _service.progress;
    final percent = (progress.percent / 100).clamp(0.0, 1.0);
    final mbReceived = (progress.received / 1024 / 1024).toStringAsFixed(1);
    final mbTotal = (progress.total / 1024 / 1024).toStringAsFixed(1);
    final statusText = switch (phase) {
      ApkDownloadPhase.downloading => progress.total > 0
          ? 'Descargando en segundo plano... ($mbReceived MB / $mbTotal MB)'
          : 'Descargando en segundo plano...',
      ApkDownloadPhase.installing => 'Descarga completa. Instalando...',
      ApkDownloadPhase.completed =>
        'Descarga completa. La instalacion se abre al volver a la app.',
      ApkDownloadPhase.error => 'Error en la actualizacion',
      ApkDownloadPhase.cancelled => 'Descarga cancelada.',
      ApkDownloadPhase.idle => 'Preparando descarga...',
    };

    return PopScope(
      canPop: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : error != null
                      ? Icons.error_rounded
                      : Icons.system_update_rounded,
                  color: completed
                      ? Colors.green
                      : error != null
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    completed
                        ? 'Actualizacion lista'
                        : error != null
                        ? 'Error en la actualizacion'
                        : 'Actualizando a ${widget.update.version}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version instalada: ${_installedVersion ?? '...'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version destino: ${widget.update.version}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
              ),
            ],
            if (downloading || installing || completed) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: downloading ? percent : 1,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (error != null) ...[
                  TextButton(onPressed: _retry, child: const Text('Reintentar')),
                  const SizedBox(width: 8),
                ],
                if (downloading)
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancelar'),
                  ),
                if (downloading) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _hide,
                    child: const Text('Continuar en segundo plano'),
                  ),
                ] else
                  FilledButton(onPressed: _hide, child: const Text('Cerrar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
