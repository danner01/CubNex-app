class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.businessId,
    this.imageUrl,
    this.imageUrls = const [],
    this.price,
    this.offerPrice,
    this.currency,
    this.sku,
    this.barcode,
    this.stock,
    this.available = true,
    this.inInventory = true,
    this.purchasable = true,
    this.features = const {},
  });

  final String id;
  final String name;
  final String? brand;
  final String? description;
  final String? businessId;
  final String? imageUrl;
  final List<String> imageUrls;
  final double? price;
  final double? offerPrice;
  final String? currency;
  final String? sku;
  final String? barcode;
  final int? stock;
  final bool available;
  final bool inInventory;
  final bool purchasable;
  final Map<String, dynamic> features;

  double? get currentPrice => offerPrice ?? price;
  bool get canBuy =>
      available && inInventory && purchasable && (stock ?? 1) > 0;

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
      imageUrls: images is List
          ? images.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList()
          : const [],
      price: double.tryParse('${json['precio'] ?? ''}'),
      offerPrice: double.tryParse('${json['precio_oferta'] ?? ''}'),
      currency: json['moneda']?.toString(),
      sku: json['sku']?.toString(),
      barcode: json['codigo_barras']?.toString(),
      stock: int.tryParse('${json['stock'] ?? ''}'),
      available: json['disponible'] != false,
      inInventory: json['en_inventario'] != false,
      purchasable: json['comprable'] != false,
      features: _parseMap(json['caracteristicas']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': name,
      'marca': brand,
      'descripcion': description,
      'negocio_id': businessId,
      'imagenes': imageUrls.isNotEmpty
          ? imageUrls
          : imageUrl == null
              ? <String>[]
              : [imageUrl],
      'precio': price,
      'precio_oferta': offerPrice,
      'moneda': currency,
      'sku': sku,
      'codigo_barras': barcode,
      'stock': stock,
      'disponible': available,
      'en_inventario': inInventory,
      'comprable': purchasable,
      'caracteristicas': features,
    };
  }

  static Map<String, dynamic> _parseMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
