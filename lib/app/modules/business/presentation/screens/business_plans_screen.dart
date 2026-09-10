import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../plans/data/models/plan_status.dart';
import '../../../plans/presentation/widgets/active_plan_card.dart';
import '../widgets/business_switcher.dart';

class BusinessPlansScreen extends StatefulWidget {
  const BusinessPlansScreen({super.key});

  @override
  State<BusinessPlansScreen> createState() => _BusinessPlansScreenState();
}

class _BusinessPlansScreenState extends State<BusinessPlansScreen> {
  late Future<_PlansData> _future;
  bool _annual = false;
  String? _submittingPlanId;
  final Map<String, String> _idempotencyKeys = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlansData> _load() async {
    final plansResult = await sl<ApiClient>().get<List<_Plan>>(
      '/suscripciones/planes',
      queryParameters: {'activo': 'eq.true', 'order': 'orden.asc'},
      parser: (json) => json is List
          ? json
                .whereType<Map>()
                .map((item) => _Plan.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
    );
    if (!plansResult.isSuccess) {
      throw StateError(
        plansResult.error?.message ?? 'No se pudieron cargar los planes.',
      );
    }

    final statusResult = await sl<ApiClient>().get<PlanStatus>(
      '/suscripciones/solicitudes-plan',
      parser: (json) => PlanStatus.fromJson(
        json is Map ? Map<String, dynamic>.from(json) : const {},
      ),
    );
    if (!statusResult.isSuccess) {
      throw StateError(
        statusResult.error?.message ??
            'No se pudo consultar el estado de tus planes.',
      );
    }
    return _PlansData(
      plans: plansResult.data ?? const [],
      status: statusResult.data ?? const PlanStatus(),
    );
  }

  void _reload() => setState(() => _future = _load());

  String _keyFor(_Plan plan, String? businessId) {
    final key = '${plan.id}:${businessId ?? 'personal'}:${_annual ? 'anual' : 'mensual'}';
    return _idempotencyKeys.putIfAbsent(
      key,
      () => 'plan-${DateTime.now().microsecondsSinceEpoch}-$key'
          .replaceAll(RegExp(r'[^A-Za-z0-9._:-]'), '-'),
    );
  }

  Future<void> _requestPlan(_Plan plan, String? businessId) async {
    final wallet = businessId == null ? 'personal' : 'del negocio';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar solicitud'),
        content: Text(
          'Se reservarán ${plan.price(_annual).toStringAsFixed(0)} granos '
          'de tu billetera $wallet hasta que SuperAdmin revise la solicitud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submittingPlanId = plan.id);
    final result = await sl<ApiClient>().post<Map<String, dynamic>>(
      '/suscripciones/solicitudes-plan',
      data: {
        'plan_id': plan.id,
        'periodo': _annual ? 'anual' : 'mensual',
        if (businessId != null) 'negocio_id': businessId,
        'idempotency_key': _keyFor(plan, businessId),
      },
      parser: (json) => json is Map
          ? Map<String, dynamic>.from(json)
          : const <String, dynamic>{},
    );
    if (!mounted) return;
    setState(() => _submittingPlanId = null);
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error?.message ?? 'No se pudo crear la solicitud del plan.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Solicitud enviada. El importe queda reservado hasta su revisión.',
        ),
      ),
    );
    _reload();
  }

  Future<void> _cancelRequest(PlanRequest request) async {
    setState(() => _submittingPlanId = request.id);
    final result = await sl<ApiClient>().post<void>(
      '/suscripciones/solicitudes-plan/${request.id}/cancelar',
      data: const {},
      parser: (_) {},
    );
    if (!mounted) return;
    setState(() => _submittingPlanId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Solicitud cancelada y fondos reembolsados a la billetera de origen.'
              : (result.error?.message ?? 'No se pudo cancelar la solicitud.'),
        ),
      ),
    );
    if (result.isSuccess) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<ActiveBusinessCubit>().state.activeBusiness;
    final businessId = business?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Planes')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<_PlansData>(
          future: _future,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                businessId == null ? 'Plan personal' : 'Planes del negocio',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                businessId == null
                    ? 'Los planes personales se cobran únicamente desde tu billetera personal.'
                    : 'Elige la modalidad para ${business?.name}. Se cobra únicamente desde la billetera del negocio.',
              ),
              BusinessSwitcher(
                onChanged: () {
                  _idempotencyKeys.clear();
                  _reload();
                },
              ),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Mensual')),
                  ButtonSegment(value: true, label: Text('Anual')),
                ],
                selected: {_annual},
                onSelectionChanged: (value) {
                  _idempotencyKeys.clear();
                  setState(() => _annual = value.first);
                },
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text('${snapshot.error}'),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!snapshot.hasData || snapshot.data!.plans.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Aún no hay planes disponibles.'),
                  ),
                )
              else ...[
                ActivePlanCard(
                  plan: snapshot.data!.status.activeFor(businessId),
                  title: 'Plan activo',
                ),
                ...snapshot.data!.status
                    .requestsFor(businessId)
                    .map(
                      (request) => _RequestCard(
                        request: request,
                        busy: _submittingPlanId == request.id,
                        onCancel: request.status == 'pendiente'
                            ? () => _cancelRequest(request)
                            : null,
                      ),
                    ),
                ...snapshot.data!.plans
                    .where(
                      (plan) =>
                          plan.supports(businessId == null) &&
                          (!_annual || plan.hasAnnual),
                    )
                    .map(
                      (plan) => _PlanCard(
                        plan: plan,
                        annual: _annual,
                        submitting: _submittingPlanId == plan.id,
                        onRequest: () => _requestPlan(plan, businessId),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    this.onCancel,
  });
  final PlanRequest request;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.pending_actions_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${request.planName} · ${request.period}'),
                Text(
                  '${request.price.toStringAsFixed(0)} granos reservados · ${request.wallet}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Estado: ${request.status}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: busy ? null : onCancel,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cancelar'),
            ),
        ],
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.annual,
    required this.submitting,
    required this.onRequest,
  });
  final _Plan plan;
  final bool annual;
  final bool submitting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final price = plan.price(annual);
    final realPrice = plan.realPrice(annual);
    final benefits = <String>[
      plan.productLimit == null
          ? 'Productos ilimitados'
          : 'Hasta ${plan.productLimit} productos',
      ...plan.privileges,
      if (plan.posts)
        plan.postsLimit == null || plan.postsLimit == 0
            ? 'Publicaciones incluidas'
            : '${plan.postsLimit} publicaciones al mes',
      if (plan.promotions) 'Promociones',
      if (plan.banners) 'Banners',
      if (plan.push) 'Notificaciones push',
      if (plan.analytics) 'Estadísticas avanzadas',
      if (plan.menu) 'Menú QR',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(plan.icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (plan.badge?.isNotEmpty == true) Chip(label: Text(plan.badge!)),
              ],
            ),
            if (plan.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(plan.description!),
              ),
            const SizedBox(height: 12),
            Text(
              '${price.toStringAsFixed(0)} granos',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (price != realPrice)
              Text(
                '${realPrice.toStringAsFixed(0)} granos',
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
            Text(annual ? 'por año' : 'por mes'),
            const SizedBox(height: 10),
            ...benefits.toSet().map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 17),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: submitting ? null : onRequest,
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Solicitar activación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlansData {
  const _PlansData({required this.plans, required this.status});
  final List<_Plan> plans;
  final PlanStatus status;
}

class _Plan {
  const _Plan({
    required this.id,
    required this.name,
    required this.monthly,
    this.annual,
    this.monthlyPromo,
    this.annualPromo,
    this.description,
    this.badge,
    this.audience = 'negocio',
    this.privileges = const [],
    this.productLimit,
    required this.posts,
    this.postsLimit,
    required this.promotions,
    required this.banners,
    required this.push,
    required this.analytics,
    required this.menu,
  });
  final String id, name, audience;
  final double monthly;
  final double? annual, monthlyPromo, annualPromo;
  final String? description, badge;
  final List<String> privileges;
  final int? productLimit, postsLimit;
  final bool posts, promotions, banners, push, analytics, menu;

  bool supports(bool personal) =>
      personal ? audience == 'personal' || audience == 'ambos' : audience == 'negocio' || audience == 'ambos';

  bool get hasAnnual => annual != null;

  double realPrice(bool annualPrice) =>
      annualPrice && annual != null ? annual! : monthly;

  double price(bool annualPrice) {
    final promotional = annualPrice ? annualPromo : monthlyPromo;
    return promotional ?? realPrice(annualPrice);
  }

  IconData get icon {
    switch (name.toLowerCase()) {
      case 'market plus':
        return Icons.diamond_rounded;
      case 'pro negocio':
        return Icons.rocket_launch_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }

  factory _Plan.fromJson(Map<String, dynamic> json) => _Plan(
    id: '${json['id'] ?? ''}',
    name: '${json['nombre'] ?? 'Plan'}',
    monthly: _number(json['precio_mensual_real'] ?? json['precio_mensual']),
    annual: (json['precio_anual_real'] ?? json['precio_anual']) == null
        ? null
        : _number(json['precio_anual_real'] ?? json['precio_anual']),
    monthlyPromo: json['precio_mensual_promocional'] == null
        ? null
        : _number(json['precio_mensual_promocional']),
    annualPromo: json['precio_anual_promocional'] == null
        ? null
        : _number(json['precio_anual_promocional']),
    description: json['descripcion']?.toString(),
    badge: json['badge']?.toString(),
    audience: '${json['audiencia'] ?? 'negocio'}',
    privileges: _strings(json['privilegios']),
    productLimit: int.tryParse('${json['limite_productos'] ?? ''}'),
    posts: json['permite_publicaciones'] == true,
    postsLimit: int.tryParse('${json['limite_publicaciones_mes'] ?? ''}'),
    promotions: json['permite_promociones'] == true,
    banners: json['permite_banners'] == true,
    push: json['permite_notificaciones_push'] == true,
    analytics: json['permite_estadisticas_avanzadas'] == true,
    menu: json['permite_qr_menu'] == true,
  );
}

double _number(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

List<String> _strings(dynamic value) => value is List
    ? value
          .map((item) => item is Map
              ? item['nombre']?.toString() ?? item['label']?.toString() ?? ''
              : item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];
