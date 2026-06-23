class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.address,
    this.postalCode,
    this.province,
    this.municipality,
    this.phone,
    this.whatsapp,
    this.openingTime,
    this.closingTime,
    this.availableNow = true,
    this.hasPhysicalLocation = true,
    this.requiresElectricity = false,
    this.hasElectricService = true,
    this.hasElectricBackup = false,
    this.electricBackupType,
    this.electricBlock,
    this.electricCircuit,
    this.availabilityUpdatedAt,
    this.rating,
    this.colors = const {},
    this.businessTypeName,
    this.businessParentCategory,
    this.businessTypeIcon,
    this.features = const {},
  });

  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String? address;
  final String? postalCode;
  final String? province;
  final String? municipality;
  final String? phone;
  final String? whatsapp;
  final String? openingTime;
  final String? closingTime;
  final bool availableNow;
  final bool hasPhysicalLocation;
  final bool requiresElectricity;
  final bool hasElectricService;
  final bool hasElectricBackup;
  final String? electricBackupType;
  final String? electricBlock;
  final String? electricCircuit;
  final String? availabilityUpdatedAt;
  final double? rating;
  final Map<String, String> colors;
  final String? businessTypeName;
  final String? businessParentCategory;
  final String? businessTypeIcon;
  final Map<String, dynamic> features;

  bool get isServiceLike =>
      businessParentCategory == 'servicio' ||
      businessParentCategory == 'transporte' ||
      businessParentCategory == 'inmobiliaria';

  bool get isFoodBusiness => businessParentCategory == 'gastronomia';

  BusinessModel copyWith({
    String? name,
    String? slug,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    String? address,
    String? postalCode,
    String? province,
    String? municipality,
    String? phone,
    String? whatsapp,
    String? openingTime,
    String? closingTime,
    bool? availableNow,
    bool? hasPhysicalLocation,
    bool? requiresElectricity,
    bool? hasElectricService,
    bool? hasElectricBackup,
    String? electricBackupType,
    String? electricBlock,
    String? electricCircuit,
    String? availabilityUpdatedAt,
    double? rating,
    Map<String, String>? colors,
    String? businessTypeName,
    String? businessParentCategory,
    String? businessTypeIcon,
    Map<String, dynamic>? features,
  }) {
    return BusinessModel(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      province: province ?? this.province,
      municipality: municipality ?? this.municipality,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      availableNow: availableNow ?? this.availableNow,
      hasPhysicalLocation: hasPhysicalLocation ?? this.hasPhysicalLocation,
      requiresElectricity: requiresElectricity ?? this.requiresElectricity,
      hasElectricService: hasElectricService ?? this.hasElectricService,
      hasElectricBackup: hasElectricBackup ?? this.hasElectricBackup,
      electricBackupType: electricBackupType ?? this.electricBackupType,
      electricBlock: electricBlock ?? this.electricBlock,
      electricCircuit: electricCircuit ?? this.electricCircuit,
      availabilityUpdatedAt:
          availabilityUpdatedAt ?? this.availabilityUpdatedAt,
      rating: rating ?? this.rating,
      colors: colors ?? this.colors,
      businessTypeName: businessTypeName ?? this.businessTypeName,
      businessParentCategory:
          businessParentCategory ?? this.businessParentCategory,
      businessTypeIcon: businessTypeIcon ?? this.businessTypeIcon,
      features: features ?? this.features,
    );
  }

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    final type = _parseMap(json['tipo_negocio']);
    return BusinessModel(
      id: '${json['id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      slug: json['slug']?.toString(),
      description: json['descripcion']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      address: json['direccion']?.toString(),
      postalCode: json['codigo_postal']?.toString(),
      province: json['provincia']?.toString(),
      municipality: json['municipio']?.toString(),
      phone: json['telefono']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      openingTime: _parseTime(json['horario_apertura']),
      closingTime: _parseTime(json['horario_cierre']),
      availableNow: json['disponible_ahora'] != false,
      hasPhysicalLocation: json['tiene_local_fisico'] != false,
      requiresElectricity: json['requiere_electricidad'] == true,
      hasElectricService: json['tiene_fluido_electrico'] != false,
      hasElectricBackup: json['tiene_respaldo_electrico'] == true,
      electricBackupType: json['tipo_respaldo_electrico']?.toString(),
      electricBlock: json['bloque_electrico']?.toString(),
      electricCircuit: json['circuito_electrico']?.toString(),
      availabilityUpdatedAt: json['disponibilidad_actualizada_at']?.toString(),
      rating: double.tryParse('${json['calificacion_promedio'] ?? ''}'),
      colors: _parseColors(json['colores']),
      businessTypeName: type['nombre']?.toString(),
      businessParentCategory: type['categoria_padre']?.toString(),
      businessTypeIcon: type['icono']?.toString(),
      features: _parseMap(json['caracteristicas']),
    );
  }

  static Map<String, String> _parseColors(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, color) => MapEntry(key.toString(), color?.toString() ?? ''),
    );
  }

  static Map<String, dynamic> _parseMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String? _parseTime(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (match == null) return text;
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }
}
