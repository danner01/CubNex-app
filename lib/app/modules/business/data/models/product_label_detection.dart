class ProductLabelDetection {
  const ProductLabelDetection({
    this.name,
    this.brand,
    this.price,
    this.currency,
    this.barcode,
    this.description,
    this.category,
    this.confidence,
  });

  final String? name;
  final String? brand;
  final double? price;
  final String? currency;
  final String? barcode;
  final String? description;
  final String? category;
  final double? confidence;

  factory ProductLabelDetection.fromJson(Map<String, dynamic> json) {
    return ProductLabelDetection(
      name: _string(json['nombre_producto'] ?? json['nombre'] ?? json['name']),
      brand: _string(json['marca'] ?? json['brand']),
      price: _double(json['precio'] ?? json['price']),
      currency: _string(json['moneda'] ?? json['currency']),
      barcode: _string(json['codigo_barras'] ?? json['barcode']),
      description: _string(
        json['descripcion_sugerida'] ?? json['descripcion'] ?? json['description'],
      ),
      category: _string(json['categoria_sugerida'] ?? json['categoria']),
      confidence: _double(json['confianza'] ?? json['confidence']),
    );
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
}
