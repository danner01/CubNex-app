class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.province,
    this.municipality,
    this.phone,
    this.whatsapp,
    this.rating,
  });

  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String? province;
  final String? municipality;
  final String? phone;
  final String? whatsapp;
  final double? rating;

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: '${json['id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      slug: json['slug']?.toString(),
      description: json['descripcion']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      province: json['provincia']?.toString(),
      municipality: json['municipio']?.toString(),
      phone: json['telefono']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      rating: double.tryParse('${json['calificacion_promedio'] ?? ''}'),
    );
  }
}
