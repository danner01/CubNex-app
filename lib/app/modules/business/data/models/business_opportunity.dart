class BusinessOpportunity {
  const BusinessOpportunity({
    required this.businessId,
    required this.name,
    required this.type,
    required this.potentialDemand,
    this.slug,
    this.logoUrl,
  });

  final String businessId;
  final String name;
  final String type;
  final int potentialDemand;
  final String? slug;
  final String? logoUrl;

  factory BusinessOpportunity.fromJson(Map<String, dynamic> json) {
    return BusinessOpportunity(
      businessId: '${json['negocio_id'] ?? ''}',
      name: '${json['nombre'] ?? 'Negocio cercano'}',
      type: '${json['tipo_negocio'] ?? 'Negocio'}',
      potentialDemand: _asInt(json['demanda_potencial_total']),
      slug: json['slug']?.toString(),
      logoUrl: json['logo_url']?.toString(),
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
