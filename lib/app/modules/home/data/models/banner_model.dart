class BannerModel {
  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: '${json['id'] ?? ''}',
      title: '${json['titulo'] ?? ''}',
      subtitle: json['subtitulo']?.toString(),
      imageUrl: json['imagen_url']?.toString(),
    );
  }
}
