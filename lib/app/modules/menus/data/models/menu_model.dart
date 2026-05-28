class MenuModel {
  const MenuModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.qrCodeUrl,
    this.publicUrl,
    this.active = true,
  });

  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String? qrCodeUrl;
  final String? publicUrl;
  final bool active;

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      name: '${json['nombre'] ?? ''}',
      description: json['descripcion']?.toString(),
      qrCodeUrl: json['qr_code_url']?.toString(),
      publicUrl: json['url_publica']?.toString(),
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
      category: json['categoria']?.toString(),
      description: json['descripcion']?.toString(),
      currency: json['moneda']?.toString(),
      imageUrl: json['imagen_url']?.toString(),
      available: json['disponible'] != false,
    );
  }
}
