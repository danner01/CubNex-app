enum MapSearchType {
  business,
  property,
  transport,
}

class MapSearchItem {
  const MapSearchItem({
    required this.id,
    required this.type,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.description,
    this.province,
    this.municipality,
    this.address,
    this.logoUrl,
    this.phone,
    this.whatsapp,
    this.price,
    this.currency,
  });

  final String id;
  final MapSearchType type;
  final String title;
  final String? description;
  final String? province;
  final String? municipality;
  final String? address;
  final String? logoUrl;
  final String? phone;
  final String? whatsapp;
  final double? price;
  final String? currency;
  final double latitude;
  final double longitude;

  String get typeLabel {
    return switch (type) {
      MapSearchType.business => 'Negocio',
      MapSearchType.property => 'Propiedad',
      MapSearchType.transport => 'Transporte',
    };
  }

  factory MapSearchItem.fromJson(
    Map<String, dynamic> json, {
    MapSearchType fallbackType = MapSearchType.business,
  }) {
    final coordinates = _extractCoordinates(json['coordenadas']);

    return MapSearchItem(
      id: '${json['id'] ?? ''}',
      type: _parseType(json['tipo_mapa'] ?? json['tipo_entidad'], fallbackType),
      title: '${json['nombre'] ?? json['titulo'] ?? 'Resultado'}',
      description: json['descripcion']?.toString(),
      province: json['provincia']?.toString(),
      municipality: json['municipio']?.toString(),
      address: json['direccion']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      phone: json['telefono']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      price: double.tryParse(
        '${json['precio'] ?? json['precio_base'] ?? json['precio_por_km'] ?? ''}',
      ),
      currency: json['moneda']?.toString(),
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }

  static MapSearchType _parseType(dynamic value, MapSearchType fallback) {
    return switch (value?.toString()) {
      'propiedad' || 'property' => MapSearchType.property,
      'transporte' || 'transport' || 'servicio_transporte' => MapSearchType.transport,
      'negocio' || 'business' => MapSearchType.business,
      _ => fallback,
    };
  }

  static _Coordinates _extractCoordinates(dynamic raw) {
    if (raw is Map) {
      final latitude = double.tryParse(
        '${raw['lat'] ?? raw['latitude'] ?? raw['y'] ?? ''}',
      );
      final longitude = double.tryParse(
        '${raw['lng'] ?? raw['lon'] ?? raw['longitude'] ?? raw['x'] ?? ''}',
      );
      if (latitude != null && longitude != null) {
        return _Coordinates(latitude: latitude, longitude: longitude);
      }
    }

    return const _Coordinates(latitude: 23.1136, longitude: -82.3666);
  }
}

class _Coordinates {
  const _Coordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
