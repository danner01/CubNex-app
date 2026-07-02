class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.businessId,
    this.businessName,
    this.businessLogoUrl,
    this.imageUrl,
    this.imageUrls = const [],
    this.price,
    this.offerPrice,
    this.transferPrice,
    this.transferPercent,
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
  final String? businessName;
  final String? businessLogoUrl;
  final String? imageUrl;
  final List<String> imageUrls;
  final double? price;
  final double? offerPrice;
  final double? transferPrice;
  final double? transferPercent;
  final String? currency;
  final String? sku;
  final String? barcode;
  final int? stock;
  final bool available;
  final bool inInventory;
  final bool purchasable;
  final Map<String, dynamic> features;

  double? get currentPrice => offerPrice ?? price;
  double? get calculatedTransferPrice {
    if (transferPrice != null) return transferPrice;
    final basePrice = currentPrice;
    if (basePrice == null || transferPercent == null) return null;
    return basePrice * (1 + (transferPercent! / 100));
  }

  bool get canBuy =>
      available && inInventory && purchasable && (stock ?? 1) > 0;

  ProductModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? description,
    String? businessId,
    String? businessName,
    String? businessLogoUrl,
    String? imageUrl,
    List<String>? imageUrls,
    double? price,
    double? offerPrice,
    double? transferPrice,
    double? transferPercent,
    String? currency,
    String? sku,
    String? barcode,
    int? stock,
    bool? available,
    bool? inInventory,
    bool? purchasable,
    Map<String, dynamic>? features,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessLogoUrl: businessLogoUrl ?? this.businessLogoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
      transferPrice: transferPrice ?? this.transferPrice,
      transferPercent: transferPercent ?? this.transferPercent,
      currency: currency ?? this.currency,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
      available: available ?? this.available,
      inInventory: inInventory ?? this.inInventory,
      purchasable: purchasable ?? this.purchasable,
      features: features ?? this.features,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final images = json['imagenes'];
    final business = _parseBusiness(json['negocios'] ?? json['negocio']);
    String? firstImage;
    if (images is List && images.isNotEmpty) {
      firstImage = images.first?.toString();
    }

    return ProductModel(
      id: '${json['id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      brand: json['marca']?.toString(),
      description: json['descripcion']?.toString(),
      businessId: json['negocio_id']?.toString() ?? business['id']?.toString(),
      businessName:
          json['negocio_nombre']?.toString() ?? business['nombre']?.toString(),
      businessLogoUrl:
          json['negocio_logo_url']?.toString() ??
          business['logo_url']?.toString(),
      imageUrl: firstImage,
      imageUrls: images is List
          ? images
                .map((item) => item?.toString() ?? '')
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      price: double.tryParse('${json['precio'] ?? ''}'),
      offerPrice: double.tryParse('${json['precio_oferta'] ?? ''}'),
      transferPrice: double.tryParse('${json['precio_transferencia'] ?? ''}'),
      transferPercent: double.tryParse(
        '${json['porciento_transferencia'] ?? ''}',
      ),
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
      'negocio_nombre': businessName,
      'negocio_logo_url': businessLogoUrl,
      'imagenes': imageUrls.isNotEmpty
          ? imageUrls
          : imageUrl == null
          ? <String>[]
          : [imageUrl],
      'precio': price,
      'precio_oferta': offerPrice,
      'precio_transferencia': transferPrice,
      'porciento_transferencia': transferPercent,
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

  static Map<String, dynamic> _parseBusiness(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }
}
