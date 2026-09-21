import 'package:flutter/material.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/tutorial_progress_store.dart';
import '../../domain/models/tutorial_definition.dart';
import 'tutorial_player_panel.dart';

/// Host global montado sobre el Navigator de la app (via `builder` de
/// MaterialApp.router). Escucha la guia pendiente del store y la ofrece al
/// entrar a una vista con tutorial no visto, o reproduce la guia en curso.
class TutorialAutoplayHost extends StatefulWidget {
  const TutorialAutoplayHost({super.key, required this.child});

  final Widget child;

  @override
  State<TutorialAutoplayHost> createState() => _TutorialAutoplayHostState();
}

class _TutorialAutoplayHostState extends State<TutorialAutoplayHost> {
  TutorialProgressStore get _store => sl<TutorialProgressStore>();
  TutorialDefinition? _offer;
  TutorialDefinition? _playing;

  @override
  void initState() {
    super.initState();
    _store.pendingOffer.addListener(_onOfferChanged);
    _offer = _store.pendingOffer.value;
  }

  @override
  void dispose() {
    _store.pendingOffer.removeListener(_onOfferChanged);
    super.dispose();
  }

  void _onOfferChanged() {
    if (!mounted) return;
    setState(() => _offer = _store.pendingOffer.value);
  }

  void _watchGuide() {
    final offer = _offer;
    if (offer == null) return;
    setState(() {
      _playing = offer;
      _offer = null;
    });
    _store.clearPending();
  }

  void _skipOffer() {
    final offer = _offer;
    if (offer == null) return;
    _store.clearPending();
    _store.markSkipped(offer.id);
  }

  @override
  Widget build(BuildContext context) {
    final playing = _playing;
    return Stack(
      children: [
        widget.child,
        if (playing != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: TutorialPlayerPanel(
              tutorial: playing,
              onClose: () => setState(() => _playing = null),
            ),
          ),
        if (_offer != null && playing == null)
          _OfferCard(
            tutorial: _offer!,
            onWatch: _watchGuide,
            onSkip: _skipOffer,
          ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.tutorial,
    required this.onWatch,
    required this.onSkip,
  });

  final TutorialDefinition tutorial;
  final VoidCallback onWatch;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: colorScheme.surface,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: Icon(tutorial.icono, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Guia disponible',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${tutorial.titulo}. ¿Quieres ver como funciona esta '
                  'seccion? Son ${tutorial.pasos.length} pasos rapidos.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onSkip,
                      child: const Text('Ahora no'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: onWatch,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Ver guia'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
