import 'package:flutter/material.dart';

import '../../data/models/plan_status.dart';

class ActivePlanCard extends StatelessWidget {
  const ActivePlanCard({
    super.key,
    required this.plan,
    this.title = 'Plan vigente',
    this.onTap,
  });

  final ActiveSubscription? plan;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = plan;
    if (active == null) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.verified_rounded),
        title: Text('$title: ${active.planName}'),
        subtitle: Text('Vigente hasta ${active.endDate}'),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}