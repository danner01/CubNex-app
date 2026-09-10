import 'package:flutter/material.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../data/models/plan_status.dart';
import 'active_plan_card.dart';

class PersonalPlanCard extends StatefulWidget {
  const PersonalPlanCard({super.key});

  @override
  State<PersonalPlanCard> createState() => _PersonalPlanCardState();
}

class _PersonalPlanCardState extends State<PersonalPlanCard> {
  late Future<ActiveSubscription?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ActiveSubscription?> _load() async {
    try {
      final result = await sl<ApiClient>().get<PlanStatus?>(
        '/suscripciones/solicitudes-plan',
        parser: (json) => json is Map
            ? PlanStatus.fromJson(Map<String, dynamic>.from(json))
            : null,
      );
      return result.data?.activeFor(null);
    } catch (_) {
      return null;
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ActiveSubscription?>(
      future: _future,
      builder: (context, snapshot) {
        final plan = snapshot.data;
        if (plan == null) return const SizedBox.shrink();
        return ActivePlanCard(plan: plan, onTap: _reload);
      },
    );
  }
}