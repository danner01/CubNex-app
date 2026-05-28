enum AssetDetailKind { property, transport }

class AssetDetailModel {
  const AssetDetailModel({
    required this.id,
    required this.kind,
    required this.title,
    this.type,
    this.description,
    this.price,
    this.currency,
    this.province,
    this.municipality,
    this.address,
    this.businessId,
    this.vehicleType,
    this.basePrice,
    this.pricePerKm,
    this.images = const [],
  });

  final String id;
  final AssetDetailKind kind;
  final String title;
  final String? type;
  final String? description;
  final double? price;
  final String? currency;
  final String? province;
  final String? municipality;
  final String? address;
  final String? businessId;
  final String? vehicleType;
  final double? basePrice;
  final double? pricePerKm;
  final List<String> images;

  String get kindLabel {
    return switch (kind) {
      AssetDetailKind.property => 'Propiedad',
      AssetDetailKind.transport => 'Transporte',
    };
  }

  factory AssetDetailModel.fromJson(
    Map<String, dynamic> json, {
    required AssetDetailKind kind,
  }) {
    return AssetDetailModel(
      id: '${json['id'] ?? ''}',
      kind: kind,
      title: '${json['titulo'] ?? json['nombre'] ?? 'Detalle'}',
      type: json['tipo']?.toString(),
      description: json['descripcion']?.toString(),
      price: double.tryParse('${json['precio'] ?? ''}'),
      currency: json['moneda']?.toString(),
      province: json['provincia']?.toString(),
      municipality: json['municipio']?.toString(),
      address: json['direccion']?.toString(),
      businessId: json['negocio_id']?.toString(),
      vehicleType: json['vehiculo_tipo']?.toString(),
      basePrice: double.tryParse('${json['precio_base'] ?? ''}'),
      pricePerKm: double.tryParse('${json['precio_por_km'] ?? ''}'),
      images: _parseImages(json['imagenes']),
    );
  }

  static List<String> _parseImages(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
