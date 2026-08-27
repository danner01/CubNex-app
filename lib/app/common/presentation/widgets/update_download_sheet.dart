import 'dart:io';

import 'package:flutter/material.dart';

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
  double _progress = 0;
  String _statusText = 'Preparando descarga...';
  bool _downloading = false;
  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _statusText = 'Descargando...';
    });

    try {
      final service = sl<ApkDownloadService>();
      final file = await service.downloadApk(
        url: widget.update.downloadUrl,
        onProgress: (progress) {
          if (!mounted) return;
          final mbReceived = (progress.received / 1024 / 1024).toStringAsFixed(1);
          final mbTotal = (progress.total / 1024 / 1024).toStringAsFixed(1);
          setState(() {
            _progress = progress.percent / 100;
            _statusText = 'Descargando... ($mbReceived MB / $mbTotal MB)';
          });
        },
      );

      if (!mounted) return;

      if (file == null) {
        setState(() {
          _error = 'No se pudo descargar el archivo.';
          _downloading = false;
        });
        return;
      }

      setState(() {
        _statusText = 'Descarga completa. Instalando...';
        _progress = 1.0;
        _completed = true;
      });

      await _installApk(file);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('cancel')) {
        setState(() {
          _statusText = 'Descarga cancelada.';
          _downloading = false;
        });
      } else {
        setState(() {
          _error = 'Error al descargar: $msg';
          _downloading = false;
        });
      }
    }
  }

  Future<void> _installApk(File file) async {
    try {
      await sl<ApkDownloadService>().installApk(file);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instalacion iniciada.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al instalar: $e\nVe a Ajustes > Aplicaciones > '
            'Permitir apps desconocidas y habilita este permiso.';
        _downloading = false;
      });
    }
  }

  void _cancel() {
    sl<ApkDownloadService>().cancelDownload();
    Navigator.of(context).pop();
  }

  void _retry() {
    setState(() {
      _error = null;
      _completed = false;
    });
    _startDownload();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _completed
                    ? Icons.check_circle_rounded
                    : _error != null
                        ? Icons.error_rounded
                        : Icons.system_update_rounded,
                color: _completed
                    ? Colors.green
                    : _error != null
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _completed
                      ? 'Actualizacion completa'
                      : _error != null
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
          if (widget.update.notes != null && widget.update.notes!.isNotEmpty) ...[
            Text(
              'Cambios en esta version:',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.update.notes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_downloading || _completed) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_error != null) ...[
                TextButton(
                  onPressed: _retry,
                  child: const Text('Reintentar'),
                ),
                const SizedBox(width: 8),
              ],
              if (_downloading)
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancelar'),
                ),
              if (!_downloading && _error == null)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
