class BusinessTypeModel {
  const BusinessTypeModel({
    required this.id,
    required this.name,
    this.slug,
    this.parentCategory,
    this.icon,
  });

  final String id;
  final String name;
  final String? slug;
  final String? parentCategory;
  final String? icon;

  factory BusinessTypeModel.fromJson(Map<String, dynamic> json) {
    return BusinessTypeModel(
      id: '${json['id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      slug: json['slug']?.toString(),
      parentCategory: json['categoria_padre']?.toString(),
      icon: json['icono']?.toString(),
    );
  }
}
