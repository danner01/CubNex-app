class BannerModel {
  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.linkUrl,
    this.businessId,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? linkUrl;
  final String? businessId;

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: '${json['id'] ?? ''}',
      title: '${json['titulo'] ?? ''}',
      subtitle: json['subtitulo']?.toString(),
      imageUrl: json['imagen_url']?.toString(),
      linkUrl: json['enlace_url']?.toString(),
      businessId: json['negocio_id']?.toString(),
    );
  }
}
