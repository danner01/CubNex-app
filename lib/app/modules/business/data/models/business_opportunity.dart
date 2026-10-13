class BusinessOpportunity {
  const BusinessOpportunity({
    required this.businessId,
    required this.name,
    required this.type,
    required this.potentialDemand,
    this.kind = 'demanda',
    this.reason,
    this.saved = false,
    this.slug,
    this.logoUrl,
  });

  final String businessId;
  final String name;
  final String type;
  final int potentialDemand;
  final String kind;
  final String? reason;
  final bool saved;
  final String? slug;
  final String? logoUrl;

  factory BusinessOpportunity.fromJson(Map<String, dynamic> json) {
    final nested = json['negocio'];
    final nestedMap = nested is Map ? Map<String, dynamic>.from(nested) : const <String, dynamic>{};
    return BusinessOpportunity(
      businessId: '${json['negocio_id'] ?? nestedMap['id'] ?? ''}',
      name: '${json['nombre'] ?? nestedMap['nombre'] ?? 'Negocio cercano'}',
      type: '${json['tipo_negocio'] ?? json['tipo'] ?? 'Negocio'}',
      potentialDemand: _asInt(json['demanda_potencial_total']),
      kind: '${json['tipo'] ?? 'demanda'}',
      reason: json['motivo']?.toString(),
      saved: json['guardada'] == true,
      slug: (json['slug'] ?? nestedMap['slug'])?.toString(),
      logoUrl: (json['logo_url'] ?? nestedMap['logo_url'])?.toString(),
    );
  }

  BusinessOpportunity copyWith({bool? saved, String? kind, String? reason}) {
    return BusinessOpportunity(
      businessId: businessId,
      name: name,
      type: type,
      potentialDemand: potentialDemand,
      kind: kind ?? this.kind,
      reason: reason ?? this.reason,
      saved: saved ?? this.saved,
      slug: slug,
      logoUrl: logoUrl,
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

class BusinessSubscriber {
  const BusinessSubscriber({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.subscribedAt,
    this.notificationsEnabled = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final DateTime? subscribedAt;
  final bool notificationsEnabled;

  factory BusinessSubscriber.fromJson(Map<String, dynamic> json) {
    return BusinessSubscriber(
      id: '${json['id'] ?? ''}',
      name: '${json['nombre'] ?? 'Cliente suscrito'}',
      avatarUrl: json['avatar_url']?.toString(),
      phone: json['telefono']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      email: json['email']?.toString(),
      address: json['direccion']?.toString(),
      subscribedAt: DateTime.tryParse('${json['suscrito_en'] ?? ''}'),
      notificationsEnabled: json['notificaciones'] == true,
    );
  }
}
