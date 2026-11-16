import 'package:flutter/material.dart';

import '../../services/offline_sync_service.dart';

/// Aviso de cambios guardados sin conexion pendientes de sincronizar y de
/// conflictos rechazados por el servidor.
class PendingSyncBanner extends StatelessWidget {
  const PendingSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = OfflineSyncService.instance;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: sync.pendingCount,
      builder: (context, pending, _) {
        return ValueListenableBuilder<List<String>>(
          valueListenable: sync.conflicts,
          builder: (context, conflicts, __) {
            if (pending == 0 && conflicts.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pending > 0
                    ? scheme.tertiaryContainer
                    : scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    pending > 0
                        ? Icons.cloud_sync_rounded
                        : Icons.warning_amber_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pending > 0
                          ? '$pending cambio(s) guardado(s) sin conexion. '
                                'Se sincronizaran al volver internet.'
                          : conflicts.last,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  if (pending == 0)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: sync.clearConflicts,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
