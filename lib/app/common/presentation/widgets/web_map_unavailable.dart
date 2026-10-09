import 'package:flutter/material.dart';

/// Reemplazo visual para las vistas con mapa (Mapbox) cuando el plugin nativo
/// no existe en la web. El mapa solo usa la app movil.
class WebMapUnavailable extends StatelessWidget {
  const WebMapUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 40,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 10),
              Text(
                'El mapa solo esta disponible en la app movil.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}