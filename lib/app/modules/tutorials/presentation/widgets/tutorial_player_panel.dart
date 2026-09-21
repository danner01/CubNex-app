import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/tutorial_progress_store.dart';
import '../../domain/models/tutorial_definition.dart';

/// Muestra una guia paso a paso. Se usa tanto dentro de un bottom sheet
/// (desde la pantalla de Tutoriales) como incrustado en el host de autoplay.
class TutorialPlayerPanel extends StatefulWidget {
  const TutorialPlayerPanel({
    super.key,
    required this.tutorial,
    required this.onClose,
    this.marcarComoVisto = true,
  });

  final TutorialDefinition tutorial;
  final VoidCallback onClose;

  /// Si es `false` el tutorial no se guarda como visto al completarse.
  final bool marcarComoVisto;

  @override
  State<TutorialPlayerPanel> createState() => _TutorialPlayerPanelState();
}

class _TutorialPlayerPanelState extends State<TutorialPlayerPanel> {
  int _index = 0;

  TutorialDefinition get _tutorial => widget.tutorial;

  bool get _isLast => _index == _tutorial.pasos.length - 1;

  Future<void> _next() async {
    if (_isLast) {
      if (widget.marcarComoVisto) {
        await sl<TutorialProgressStore>().markSeen(_tutorial.id);
      }
      widget.onClose();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _index += 1);
  }

  Future<void> _skip() async {
    HapticFeedback.selectionClick();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final step = _tutorial.pasos[_index];
    final progress = _index + 1;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: Icon(_tutorial.icono, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guia de ${_tutorial.titulo}',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Paso $progress de ${_tutorial.pasos.length}',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Container(
                  key: ValueKey(step.titulo),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        child: Icon(step.icono, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.titulo,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(step.descripcion, style: textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _tutorial.pasos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(onPressed: _skip, child: const Text('Omitir')),
                  const Spacer(),
                  if (_isLast)
                    FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Entendido'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Siguiente'),
                      iconAlignment: IconAlignment.end,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre la guia como modal bottom sheet (pantalla de Tutoriales).
Future<void> showTutorialPlayer(
  BuildContext context,
  TutorialDefinition tutorial, {
  bool marcarComoVisto = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TutorialPlayerPanel(
      tutorial: tutorial,
      marcarComoVisto: marcarComoVisto,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}
