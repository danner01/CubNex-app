class PlanStatus {
  const PlanStatus({
    this.requests = const [],
    this.businessSubscriptions = const [],
    this.personalSubscription,
  });

  final List<PlanRequest> requests;
  final List<ActiveSubscription> businessSubscriptions;
  final ActiveSubscription? personalSubscription;

  factory PlanStatus.fromJson(Map<String, dynamic> json) => PlanStatus(
        requests: _maps(json['solicitudes'])
            .map(PlanRequest.fromJson)
            .toList(),
        businessSubscriptions: _maps(
          json['suscripciones_negocio'],
        ).map(ActiveSubscription.fromJson).toList(),
        personalSubscription: json['suscripcion_personal'] is Map
            ? ActiveSubscription.fromJson(
                Map<String, dynamic>.from(
                  json['suscripcion_personal'] as Map,
                ),
              )
            : null,
      );

  Iterable<PlanRequest> requestsFor(String? businessId) => requests.where(
        (request) => businessId == null
            ? request.businessId == null
            : request.businessId == businessId,
      );

  ActiveSubscription? activeFor(String? businessId) {
    if (businessId == null) return personalSubscription;
    for (final subscription in businessSubscriptions) {
      if (subscription.businessId == businessId) return subscription;
    }
    return null;
  }
}

class PlanRequest {
  const PlanRequest({
    required this.id,
    required this.status,
    required this.period,
    required this.wallet,
    required this.price,
    this.businessId,
    this.planName = 'Plan',
  });

  final String id, status, period, wallet, planName;
  final double price;
  final String? businessId;

  factory PlanRequest.fromJson(Map<String, dynamic> json) {
    final plan = json['planes_suscripcion'];
    return PlanRequest(
      id: '${json['id'] ?? ''}',
      status: '${json['estado'] ?? 'pendiente'}',
      period: '${json['periodo'] ?? 'mensual'}',
      wallet: '${json['wallet_origen'] ?? 'personal'}',
      price: _number(json['precio_reservado']),
      businessId: json['negocio_id']?.toString(),
      planName: plan is Map ? '${plan['nombre'] ?? 'Plan'}' : 'Plan',
    );
  }
}

class ActiveSubscription {
  const ActiveSubscription({
    required this.planName,
    required this.endDate,
    this.businessId,
  });

  final String planName, endDate;
  final String? businessId;

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) {
    final plan = json['planes_suscripcion'];
    final rawEnd = json['fecha_fin']?.toString();
    final end = DateTime.tryParse(rawEnd ?? '');
    return ActiveSubscription(
      planName: plan is Map ? '${plan['nombre'] ?? 'Plan'}' : 'Plan',
      endDate: end == null
          ? (rawEnd ?? '—')
          : '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}',
      businessId: json['negocio_id']?.toString(),
    );
  }
}

double _number(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : const [];