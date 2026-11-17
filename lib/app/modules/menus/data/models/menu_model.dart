class MenuModel {
  const MenuModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.qrCodeUrl,
    this.publicUrl,
    this.slug,
    this.active = true,
  });

  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String? qrCodeUrl;
  final String? publicUrl;
  final String? slug;
  final bool active;

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      description: json['descripcion']?.toString(),
      qrCodeUrl: json['qr_code_url']?.toString(),
      publicUrl: json['url_publica']?.toString(),
      slug: json['slug_publico']?.toString(),
      active: json['activo'] != false,
    );
  }
}

class MenuItemModel {
  const MenuItemModel({
    required this.id,
    required this.menuId,
    required this.name,
    required this.price,
    this.productId,
    this.category,
    this.description,
    this.currency,
    this.imageUrl,
    this.available = true,
  });

  final String id;
  final String menuId;
  final String name;
  final double price;
  final String? productId;
  final String? category;
  final String? description;
  final String? currency;
  final String? imageUrl;
  final bool available;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: '${json['id'] ?? ''}',
      menuId: '${json['menu_id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      price: double.tryParse('${json['precio'] ?? ''}') ?? 0,
      productId: json['producto_id']?.toString(),
      category: json['categoria']?.toString(),
      description: json['descripcion']?.toString(),
      currency: json['moneda']?.toString(),
      imageUrl: json['imagen_url']?.toString(),
      available: json['disponible'] != false,
    );
  }
}

/// Carta publica de un negocio, con los datos para mostrarla con su tema.
class PublicCartaModel {
  const PublicCartaModel({
    required this.menuName,
    required this.businessId,
    required this.businessName,
    required this.colors,
    required this.items,
    this.menuDescription,
    this.businessDescription,
    this.logoUrl,
    this.bannerUrl,
    this.address,
    this.location,
    this.phone,
    this.whatsapp,
    this.schedule,
  });

  final String menuName;
  final String? menuDescription;
  final String businessId;
  final String businessName;
  final String? businessDescription;
  final String? logoUrl;
  final String? bannerUrl;
  final String? address;
  final String? location;
  final String? phone;
  final String? whatsapp;
  final String? schedule;
  final Map<String, String> colors;
  final List<MenuItemModel> items;

  factory PublicCartaModel.fromJson(Map<String, dynamic> json) {
    final menu = json['menu'] is Map
        ? Map<String, dynamic>.from(json['menu'] as Map)
        : <String, dynamic>{};
    final business = menu['negocios'] is Map
        ? Map<String, dynamic>.from(menu['negocios'] as Map)
        : <String, dynamic>{};
    final colors = <String, String>{};
    final rawColors = business['colores'];
    if (rawColors is Map) {
      rawColors.forEach((key, value) {
        if (value != null) colors['$key'] = '$value';
      });
    }
    final tema = menu['tema'];
    if (tema is Map) {
      tema.forEach((key, value) {
        if (value != null && '$value'.isNotEmpty) colors['$key'] = '$value';
      });
    }
    String? text(Object? value) {
      final result = value?.toString().trim();
      return result == null || result.isEmpty ? null : result;
    }

    final items = json['items'] is List
        ? (json['items'] as List)
              .whereType<Map>()
              .map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <MenuItemModel>[];
    return PublicCartaModel(
      menuName: text(menu['nombre']) ?? 'Carta',
      menuDescription: text(menu['descripcion']),
      businessId: text(menu['negocio_id']) ?? '',
      businessName: text(business['nombre']) ?? text(menu['nombre']) ?? 'Carta',
      businessDescription: text(business['descripcion']),
      logoUrl: text(business['logo_url']),
      bannerUrl: text(business['banner_url']),
      address: text(business['direccion']),
      location: [business['municipio'], business['provincia']]
          .map(text)
          .whereType<String>()
          .join(', '),
      phone: text(business['telefono']),
      whatsapp: text(business['whatsapp']),
      schedule: text(business['horario']),
      colors: colors,
      items: items,
    );
  }
}
