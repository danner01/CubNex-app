class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.businessId,
    this.imageUrl,
    this.price,
    this.offerPrice,
    this.currency,
  });

  final String id;
  final String name;
  final String? brand;
  final String? description;
  final String? businessId;
  final String? imageUrl;
  final double? price;
  final double? offerPrice;
  final String? currency;

  double? get currentPrice => offerPrice ?? price;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final images = json['imagenes'];
    String? firstImage;
    if (images is List && images.isNotEmpty) {
      firstImage = images.first?.toString();
    }

    return ProductModel(
      id: '${json['id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      brand: json['marca']?.toString(),
      description: json['descripcion']?.toString(),
      businessId: json['negocio_id']?.toString(),
      imageUrl: firstImage,
      price: double.tryParse('${json['precio'] ?? ''}'),
      offerPrice: double.tryParse('${json['precio_oferta'] ?? ''}'),
      currency: json['moneda']?.toString(),
    );
  }
}
