import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/gamification/gamification_cubit.dart';
import '../../blocs/gamification/gamification_state.dart';
import '../../data/models/gamification_level.dart';

class GamificationScreen extends StatelessWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GamificationCubit>()..load(),
      child: const _GamificationView(),
    );
  }
}

class _GamificationView extends StatelessWidget {
  const _GamificationView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<GamificationCubit, GamificationState>(
        builder: (context, state) {
          final summary = state.summary;
          final nextLevel = summary == null
              ? null
              : _nextLevel(state.levels, summary.points);
          final currentMin = summary == null
              ? 0
              : _currentLevelMin(state.levels, summary.level);
          final nextMin = nextLevel?.minimumPoints ?? summary?.points ?? 0;
          final progress = summary == null || nextMin <= currentMin
              ? 1.0
              : ((summary.points - currentMin) / (nextMin - currentMin))
                    .clamp(0.0, 1.0);

          return RefreshIndicator(
            onRefresh: () => context.read<GamificationCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Puntos y nivel',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Progreso, cashback, sorteos y recompensas.'),
                const SizedBox(height: 16),
                if (state.status == GamificationStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (summary == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No hay datos de gamificacion todavia.'),
                    ),
                  )
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${summary.points} pts',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nivel ${summary.level.toUpperCase()}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 8),
                          Text(
                            nextLevel == null
                                ? 'Ya estas en el nivel mas alto disponible.'
                                : '${nextLevel.minimumPoints - summary.points} pts para ${nextLevel.name}.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Compras',
                          value: '${summary.totalPurchases}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          label: 'Resenas',
                          value: '${summary.totalReviews}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Movimientos recientes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (summary.recentMovements.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Aun no hay movimientos.'),
                      ),
                    )
                  else
                    ...summary.recentMovements.map((movement) {
                      final date = movement.createdAt == null
                          ? 'Sin fecha'
                          : DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(movement.createdAt!);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.stars_rounded),
                          title: Text(movement.description ?? movement.type),
                          subtitle: Text(date),
                          trailing: Text(
                            '+${movement.points}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  GamificationLevel? _nextLevel(List<GamificationLevel> levels, int points) {
    final sorted = [...levels]
      ..sort((a, b) => a.minimumPoints.compareTo(b.minimumPoints));
    for (final level in sorted) {
      if (level.minimumPoints > points) return level;
    }
    return null;
  }

  int _currentLevelMin(List<GamificationLevel> levels, String current) {
    for (final level in levels) {
      if (level.name == current) return level.minimumPoints;
    }
    return 0;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
