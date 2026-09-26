import '../../../home/data/models/business_model.dart';

class BusinessPostModel {
  const BusinessPostModel({
    required this.id,
    required this.businessId,
    required this.content,
    this.title,
    this.type = 'post',
    this.mediaUrls = const [],
    this.mediaType = 'imagen',
    this.tags = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.views = 0,
    this.savesCount = 0,
    this.status = 'publicado',
    this.moderationStatus = 'aprobado',
    this.rejectionReason,
    this.scheduledAt,
    this.publishedAt,
    this.linkUrl,
    this.ctaText,
    this.precio,
    this.createdAt,
    this.business,
  });

  final String id;
  final String businessId;
  final String? title;
  final String content;
  final String type;
  final List<String> mediaUrls;
  final String mediaType;
  final List<String> tags;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int views;
  final int savesCount;
  final String status;
  final String moderationStatus;
  final String? rejectionReason;
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final String? linkUrl;
  final String? ctaText;
  final double? precio;
  final DateTime? createdAt;
  final BusinessModel? business;

  factory BusinessPostModel.fromJson(Map<String, dynamic> json) {
    return BusinessPostModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      title: json['titulo']?.toString(),
      content: '${json['contenido'] ?? ''}',
      type: json['tipo']?.toString() ?? 'post',
      mediaUrls: _stringList(json['media_urls']),
      mediaType: json['media_tipo']?.toString() ?? 'imagen',
      tags: _stringList(json['tags']),
      likesCount: int.tryParse('${json['likes_count'] ?? 0}') ?? 0,
      commentsCount: int.tryParse('${json['comentarios_count'] ?? 0}') ?? 0,
      sharesCount: int.tryParse('${json['compartidos_count'] ?? 0}') ?? 0,
      views: int.tryParse('${json['vistas'] ?? 0}') ?? 0,
      savesCount: int.tryParse('${json['guardados_count'] ?? 0}') ?? 0,
      status: json['estado']?.toString() ?? 'publicado',
      moderationStatus: json['estado_moderacion']?.toString() ?? 'aprobado',
      rejectionReason: json['motivo_rechazo']?.toString(),
      scheduledAt: DateTime.tryParse('${json['fecha_programada'] ?? ''}'),
      publishedAt: DateTime.tryParse('${json['publicado_at'] ?? ''}'),
      linkUrl: json['enlace_url']?.toString(),
      ctaText: json['cta_texto']?.toString(),
      precio: _num(json['precio']),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      business: json['negocios'] is Map
          ? BusinessModel.fromJson(
              Map<String, dynamic>.from(json['negocios'] as Map),
            )
          : null,
    );
  }

  BusinessPostModel copyWith({
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
  }) {
    return BusinessPostModel(
      id: id,
      businessId: businessId,
      title: title,
      content: content,
      type: type,
      mediaUrls: mediaUrls,
      mediaType: mediaType,
      tags: tags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      views: views,
      savesCount: savesCount,
      status: status,
      moderationStatus: moderationStatus,
      rejectionReason: rejectionReason,
      scheduledAt: scheduledAt,
      publishedAt: publishedAt,
      linkUrl: linkUrl,
      ctaText: ctaText,
      precio: precio,
      createdAt: createdAt,
      business: business,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static double? _num(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

class PostCommentModel {
  const PostCommentModel({
    required this.id,
    required this.postId,
    required this.comment,
    this.userName,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String postId;
  final String comment;
  final String? userName;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    final profile = json['perfiles'] is Map
        ? Map<String, dynamic>.from(json['perfiles'] as Map)
        : const <String, dynamic>{};

    return PostCommentModel(
      id: '${json['id'] ?? ''}',
      postId: '${json['publicacion_id'] ?? ''}',
      comment: '${json['comentario'] ?? ''}',
      userName: profile['nombre_completo']?.toString(),
      avatarUrl: profile['avatar_url']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
