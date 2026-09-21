import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/tutorial_progress_store.dart';
import '../../data/tutorial_catalog.dart';
import '../../domain/models/tutorial_definition.dart';
import '../widgets/tutorial_player_panel.dart';

class TutorialsScreen extends StatefulWidget {
  const TutorialsScreen({super.key});

  @override
  State<TutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<TutorialsScreen> {
  TutorialProgressStore get _store => sl<TutorialProgressStore>();

  @override
  void initState() {
    super.initState();
    _store.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    _store.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (!mounted) return;
    setState(() {});
  }

  String _modeLabel(RoleMode mode) {
    return switch (mode) {
      RoleMode.client => 'cliente',
      RoleMode.business => 'negocio',
      RoleMode.delivery => 'delivery',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final activeMode = context.watch<RoleModeCubit>().state.activeMode;
    final roleTutorials = TutorialCatalog.roleScopedForMode(activeMode);
    final transversal = TutorialCatalog.transversal();

    return Scaffold(
      appBar: AppBar(title: const Text('Tutoriales')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guia para aprender a usar la app',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toca una guia para reproducirla. Cuando la '
                          'completes queda marcada como vista.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (roleTutorials.isNotEmpty) ...[
            _SectionHeader(
              title: 'Tutoriales de tu rol de $_modeLabel(activeMode)',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final tutorial in roleTutorials)
                    _TutorialTile(tutorial: tutorial),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          _SectionHeader(
            title: 'Transversales a todos los roles',
            icon: Icons.all_inclusive_rounded,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final tutorial in transversal)
                  _TutorialTile(tutorial: tutorial),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _TutorialTile extends StatelessWidget {
  const _TutorialTile({required this.tutorial});

  final TutorialDefinition tutorial;

  @override
  Widget build(BuildContext context) {
    final store = sl<TutorialProgressStore>();
    final colorScheme = Theme.of(context).colorScheme;
    final seen = store.isSeen(tutorial.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: Icon(tutorial.icono, size: 20),
      ),
      title: Text(
        tutorial.titulo,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        tutorial.descripcion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: seen
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Visto',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Nuevo',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
      onTap: () => showTutorialPlayer(context, tutorial),
    );
  }
}
