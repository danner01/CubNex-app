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
    this.colors = const {},
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
  final Map<String, String> colors;

  BusinessModel copyWith({
    String? name,
    String? slug,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    String? province,
    String? municipality,
    String? phone,
    String? whatsapp,
    double? rating,
    Map<String, String>? colors,
  }) {
    return BusinessModel(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      province: province ?? this.province,
      municipality: municipality ?? this.municipality,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      rating: rating ?? this.rating,
      colors: colors ?? this.colors,
    );
  }

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
      colors: _parseColors(json['colores']),
    );
  }

  static Map<String, String> _parseColors(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, color) => MapEntry(key.toString(), color?.toString() ?? ''),
    );
  }
}
