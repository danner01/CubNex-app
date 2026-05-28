class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.imageUrl,
    this.link,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String? imageUrl;
  final String? link;
  final bool read;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: '${json['id'] ?? ''}',
      type: '${json['tipo'] ?? 'sistema'}',
      title: '${json['titulo'] ?? ''}',
      message: '${json['mensaje'] ?? ''}',
      imageUrl: json['imagen_url']?.toString(),
      link: json['enlace']?.toString(),
      read: json['leida'] == true,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
