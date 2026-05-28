class PromotionModel {
  const PromotionModel({
    required this.id,
    required this.businessId,
    required this.type,
    required this.title,
    this.description,
    this.imageUrl,
    this.code,
    this.value,
    this.percent,
    this.requiredPoints,
    this.startAt,
    this.endAt,
    this.active = true,
  });

  final String id;
  final String businessId;
  final String type;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? code;
  final double? value;
  final int? percent;
  final int? requiredPoints;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool active;

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      type: '${json['tipo'] ?? 'descuento'}',
      title: '${json['titulo'] ?? ''}',
      description: json['descripcion']?.toString(),
      imageUrl: json['imagen_url']?.toString(),
      code: json['codigo']?.toString(),
      value: _double(json['valor']),
      percent: _int(json['porcentaje']),
      requiredPoints: _int(json['puntos_requeridos']),
      startAt: DateTime.tryParse('${json['fecha_inicio'] ?? ''}'),
      endAt: DateTime.tryParse('${json['fecha_fin'] ?? ''}'),
      active: json['activo'] != false,
    );
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }
}
