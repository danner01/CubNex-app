class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.businessId,
    required this.rating,
    this.userId,
    this.comment,
    this.businessResponse,
    this.usefulCount = 0,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String? userId;
  final int rating;
  final String? comment;
  final String? businessResponse;
  final int usefulCount;
  final DateTime? createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      userId: json['usuario_id']?.toString(),
      rating: _int(json['calificacion'], fallback: 0),
      comment: json['comentario']?.toString(),
      businessResponse: json['respuesta_negocio']?.toString(),
      usefulCount: _int(json['util_count'], fallback: 0),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  static int _int(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }
}
