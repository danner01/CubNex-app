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
    this.acceptsTransfer = false,
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
    this.businessTypeSlug,
    this.businessParentCategory,
    this.businessTypeIcon,
    this.features = const {},
    this.accessType = 'propietario',
    this.employeeId,
    this.employeeRoleTitle,
    this.employeeIsDelivery = false,
    this.employeePermissions = const {},
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
  final bool acceptsTransfer;
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
  final String? businessTypeSlug;
  final String? businessParentCategory;
  final String? businessTypeIcon;
  final Map<String, dynamic> features;
  final String accessType;
  final String? employeeId;
  final String? employeeRoleTitle;
  final bool employeeIsDelivery;
  final Map<String, bool> employeePermissions;

  bool get isOwnerAccess => accessType != 'empleado';

  bool get isEmployeeAccess => accessType == 'empleado';

  bool canEmployee(String permission) {
    if (isOwnerAccess) return true;
    return employeePermissions[permission] == true;
  }

  bool get isServiceLike =>
      businessParentCategory == 'servicio' ||
      businessParentCategory == 'transporte' ||
      businessParentCategory == 'inmobiliaria';

  bool get isFoodBusiness => businessParentCategory == 'gastronomia';

  bool get isFuelBusiness => businessTypeSlug == 'venta-combustible';

  bool get isCurrencyExchangeBusiness => businessTypeSlug == 'casa-cambio';

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
    bool? acceptsTransfer,
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
    String? businessTypeSlug,
    String? businessParentCategory,
    String? businessTypeIcon,
    Map<String, dynamic>? features,
    String? accessType,
    String? employeeId,
    String? employeeRoleTitle,
    bool? employeeIsDelivery,
    Map<String, bool>? employeePermissions,
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
      acceptsTransfer: acceptsTransfer ?? this.acceptsTransfer,
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
      businessTypeSlug: businessTypeSlug ?? this.businessTypeSlug,
      businessParentCategory:
          businessParentCategory ?? this.businessParentCategory,
      businessTypeIcon: businessTypeIcon ?? this.businessTypeIcon,
      features: features ?? this.features,
      accessType: accessType ?? this.accessType,
      employeeId: employeeId ?? this.employeeId,
      employeeRoleTitle: employeeRoleTitle ?? this.employeeRoleTitle,
      employeeIsDelivery: employeeIsDelivery ?? this.employeeIsDelivery,
      employeePermissions: employeePermissions ?? this.employeePermissions,
    );
  }

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    final type = _parseMap(json['tipo_negocio']);
    final access = _parseMap(json['acceso']);
    final rawPermissions = access['permisos'];
    final permissions = <String, bool>{};
    if (rawPermissions is Map) {
      for (final entry in rawPermissions.entries) {
        final value = entry.value;
        permissions[entry.key.toString()] =
            value == true || value == 1 || value == 'true';
      }
    }
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
      acceptsTransfer: json['acepta_transferencia'] == true,
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
      businessTypeSlug: type['slug']?.toString(),
      businessParentCategory: type['categoria_padre']?.toString(),
      businessTypeIcon: type['icono']?.toString(),
      features: _parseMap(json['caracteristicas']),
      accessType: '${access['tipo'] ?? 'propietario'}',
      employeeId: access['empleado_id']?.toString(),
      employeeRoleTitle: access['cargo']?.toString(),
      employeeIsDelivery: access['es_delivery'] == true,
      employeePermissions: permissions,
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
