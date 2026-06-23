class FavoriteModel {
  const FavoriteModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String? title;
  final String? subtitle;
  final String? imageUrl;
  final DateTime? createdAt;

  String get label {
    return switch (entityType) {
      'producto' => 'Producto',
      'negocio' => 'Negocio',
      'propiedad' => 'Propiedad',
      'servicio' => 'Servicio',
      _ => entityType,
    };
  }

  FavoriteModel copyWith({
    String? title,
    String? subtitle,
    String? imageUrl,
  }) {
    return FavoriteModel(
      id: id,
      entityType: entityType,
      entityId: entityId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
    );
  }

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: '${json['id'] ?? ''}',
      entityType: '${json['tipo_entidad'] ?? ''}',
      entityId: '${json['entidad_id'] ?? ''}',
      title: json['titulo']?.toString() ?? json['nombre']?.toString(),
      subtitle: json['descripcion']?.toString(),
      imageUrl: json['imagen_url']?.toString() ?? json['logo_url']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
