class ProductLabelDetection {
  const ProductLabelDetection({
    this.name,
    this.brand,
    this.price,
    this.currency,
    this.barcode,
    this.description,
    this.category,
    this.size,
    this.weight,
    this.volume,
    this.unit,
    this.manufacturer,
    this.originCountry,
    this.ingredients = const [],
    this.properties = const {},
    this.imageUrls = const [],
    this.frontImageUrl,
    this.backImageUrl,
    this.confidence,
  });

  final String? name;
  final String? brand;
  final double? price;
  final String? currency;
  final String? barcode;
  final String? description;
  final String? category;
  final String? size;
  final String? weight;
  final String? volume;
  final String? unit;
  final String? manufacturer;
  final String? originCountry;
  final List<String> ingredients;
  final Map<String, dynamic> properties;
  final List<String> imageUrls;
  final String? frontImageUrl;
  final String? backImageUrl;
  final double? confidence;

  factory ProductLabelDetection.fromJson(Map<String, dynamic> json) {
    return ProductLabelDetection(
      name: _string(json['nombre_producto'] ?? json['nombre'] ?? json['name']),
      brand: _string(json['marca'] ?? json['brand']),
      price: _double(json['precio'] ?? json['price']),
      currency: _string(json['moneda'] ?? json['currency']),
      barcode: _string(json['codigo_barras'] ?? json['barcode']),
      description: _string(
        json['descripcion_sugerida'] ??
            json['descripcion'] ??
            json['description'],
      ),
      category: _string(json['categoria_sugerida'] ?? json['categoria']),
      size: _string(json['tamano'] ?? json['size']),
      weight: _string(json['peso'] ?? json['weight']),
      volume: _string(json['volumen'] ?? json['volume']),
      unit: _string(json['unidad_medida'] ?? json['unit']),
      manufacturer: _string(json['fabricante'] ?? json['manufacturer']),
      originCountry: _string(json['pais_origen'] ?? json['origin_country']),
      ingredients: _stringList(json['ingredientes'] ?? json['ingredients']),
      properties: _map(json['propiedades'] ?? json['properties']),
      imageUrls: _stringList(json['imagenes_urls'] ?? json['image_urls']),
      frontImageUrl: _string(
        json['imagen_frente_url'] ?? json['front_image_url'],
      ),
      backImageUrl: _string(
        json['imagen_reverso_url'] ?? json['back_image_url'],
      ),
      confidence: _double(json['confianza'] ?? json['confidence']),
    );
  }

  Map<String, dynamic> toProductFeatures({String? category}) {
    return {
      if ((category ?? this.category)?.trim().isNotEmpty == true)
        'categoria': (category ?? this.category)!.trim(),
      if (size != null) 'tamano': size,
      if (weight != null) 'peso': weight,
      if (volume != null) 'volumen': volume,
      if (unit != null) 'unidad_medida': unit,
      if (manufacturer != null) 'fabricante': manufacturer,
      if (originCountry != null) 'pais_origen': originCountry,
      if (ingredients.isNotEmpty) 'ingredientes': ingredients,
      if (properties.isNotEmpty) ...properties,
      'deteccion_ia': true,
    };
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => _string(item))
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = _string(value);
    return text == null ? const [] : [text];
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
