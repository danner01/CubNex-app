class BusinessTypeModel {
  const BusinessTypeModel({
    required this.id,
    required this.name,
    this.slug,
    this.parentCategory,
    this.icon,
    this.requiredFields = const [],
  });

  final String id;
  final String name;
  final String? slug;
  final String? parentCategory;
  final String? icon;
  final List<Map<String, dynamic>> requiredFields;

  factory BusinessTypeModel.fromJson(Map<String, dynamic> json) {
    return BusinessTypeModel(
      id: '${json['id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      slug: json['slug']?.toString(),
      parentCategory: json['categoria_padre']?.toString(),
      icon: json['icono']?.toString(),
      requiredFields: (json['campos_requeridos'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }
}
