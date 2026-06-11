enum MapSearchType { business, property, transport }

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
    this.bannerUrl,
    this.themeColor,
    this.typeIcon,
    this.phone,
    this.whatsapp,
    this.availableNow = true,
    this.requiresElectricity = false,
    this.hasElectricService = true,
    this.hasElectricBackup = false,
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
  final String? bannerUrl;
  final String? themeColor;
  final String? typeIcon;
  final String? phone;
  final String? whatsapp;
  final bool availableNow;
  final bool requiresElectricity;
  final bool hasElectricService;
  final bool hasElectricBackup;
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
      bannerUrl: json['banner_url']?.toString(),
      themeColor: _parseThemeColor(json['colores']),
      typeIcon: json['icono']?.toString() ?? json['tipo_icono']?.toString(),
      phone: json['telefono']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      availableNow: json['disponible_ahora'] != false,
      requiresElectricity: json['requiere_electricidad'] == true,
      hasElectricService: json['tiene_fluido_electrico'] != false,
      hasElectricBackup: json['tiene_respaldo_electrico'] == true,
      price: double.tryParse(
        '${json['precio'] ?? json['precio_base'] ?? json['precio_por_km'] ?? ''}',
      ),
      currency: json['moneda']?.toString(),
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }

  String? get imageUrl {
    final banner = bannerUrl?.trim();
    if (banner != null && banner.isNotEmpty) return banner;
    final logo = logoUrl?.trim();
    if (logo != null && logo.isNotEmpty) return logo;
    return null;
  }

  static MapSearchType _parseType(dynamic value, MapSearchType fallback) {
    return switch (value?.toString()) {
      'propiedad' || 'property' => MapSearchType.property,
      'transporte' ||
      'transport' ||
      'servicio_transporte' => MapSearchType.transport,
      'negocio' || 'business' => MapSearchType.business,
      _ => fallback,
    };
  }

  static String? _parseThemeColor(dynamic raw) {
    if (raw is! Map) return null;
    final colors = Map<Object?, Object?>.from(raw);
    return (colors['primario'] ?? colors['acento'] ?? colors['primary'])
        ?.toString();
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
