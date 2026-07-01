class JobModel {
  const JobModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.role,
    this.description,
    this.requirements,
    this.schedule,
    this.modality,
    this.salaryMin,
    this.salaryMax,
    this.currency = 'CUP',
    this.bannerUrl,
    this.contactName,
    this.contactPhone,
    this.contactWhatsapp,
    this.contactEmail,
    this.province,
    this.municipality,
    this.expiresAt,
    this.active = true,
    this.businessName,
    this.businessLogoUrl,
  });

  final String id;
  final String businessId;
  final String title;
  final String role;
  final String? description;
  final String? requirements;
  final String? schedule;
  final String? modality;
  final double? salaryMin;
  final double? salaryMax;
  final String currency;
  final String? bannerUrl;
  final String? contactName;
  final String? contactPhone;
  final String? contactWhatsapp;
  final String? contactEmail;
  final String? province;
  final String? municipality;
  final String? expiresAt;
  final bool active;
  final String? businessName;
  final String? businessLogoUrl;

  String get salaryLabel {
    if (salaryMin == null && salaryMax == null) return 'Salario a convenir';
    if (salaryMin != null && salaryMax != null) {
      return '${salaryMin!.toStringAsFixed(0)} - ${salaryMax!.toStringAsFixed(0)} $currency';
    }
    return '${(salaryMin ?? salaryMax)!.toStringAsFixed(0)} $currency';
  }

  String get locationLabel {
    final parts = [municipality, province]
        .where((value) => value != null && value.trim().isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? 'Ubicacion por confirmar' : parts.join(', ');
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final business = json['negocios'] is Map
        ? Map<String, dynamic>.from(json['negocios'] as Map)
        : const <String, dynamic>{};
    return JobModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      title: '${json['titulo'] ?? ''}',
      role: '${json['cargo'] ?? ''}',
      description: json['descripcion']?.toString(),
      requirements: json['requisitos']?.toString(),
      schedule: json['horario']?.toString(),
      modality: json['modalidad']?.toString(),
      salaryMin: double.tryParse('${json['salario_min'] ?? ''}'),
      salaryMax: double.tryParse('${json['salario_max'] ?? ''}'),
      currency: json['moneda']?.toString() ?? 'CUP',
      bannerUrl: json['banner_url']?.toString(),
      contactName: json['contacto_nombre']?.toString(),
      contactPhone: json['contacto_telefono']?.toString(),
      contactWhatsapp: json['contacto_whatsapp']?.toString(),
      contactEmail: json['contacto_email']?.toString(),
      province:
          json['provincia']?.toString() ?? business['provincia']?.toString(),
      municipality:
          json['municipio']?.toString() ?? business['municipio']?.toString(),
      expiresAt: json['fecha_caducidad']?.toString(),
      active: json['activo'] != false,
      businessName: business['nombre']?.toString(),
      businessLogoUrl: business['logo_url']?.toString(),
    );
  }
}
