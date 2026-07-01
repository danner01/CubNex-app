class OrderModel {
  const OrderModel({
    required this.id,
    required this.businessId,
    this.items = const [],
    this.productId,
    this.propertyId,
    this.transportId,
    this.type,
    this.status,
    this.contactName,
    this.phone,
    this.email,
    this.message,
    this.quantity,
    this.currency,
    this.estimatedTotal,
    this.metadata,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final List<OrderItemModel> items;
  final String? productId;
  final String? propertyId;
  final String? transportId;
  final String? type;
  final String? status;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? message;
  final int? quantity;
  final String? currency;
  final double? estimatedTotal;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  String get title {
    if (items.isNotEmpty) {
      if (items.length == 1) return items.first.name;
      return '${items.length} productos reservados';
    }

    final metadataTitle =
        metadata?['producto_nombre'] ??
        metadata?['titulo'] ??
        metadata?['nombre'];
    if (metadataTitle != null && '$metadataTitle'.isNotEmpty) {
      return '$metadataTitle';
    }

    return switch (type) {
      'producto' => 'Solicitud de producto',
      'propiedad' => 'Solicitud de propiedad',
      'transporte' => 'Solicitud de transporte',
      'servicio' => 'Solicitud de servicio',
      _ => 'Solicitud comercial',
    };
  }

  String get typeLabel {
    return switch (type) {
      'producto' => 'Producto',
      'propiedad' => 'Propiedad',
      'transporte' => 'Transporte',
      'servicio' => 'Servicio',
      'general' => 'General',
      _ => type ?? 'General',
    };
  }

  String get statusLabel {
    return switch (status) {
      'nuevo' => 'Nuevo',
      'contactado' => 'Contactado',
      'en_proceso' => 'En proceso',
      'cerrado' => 'Cerrado',
      'cancelado' => 'Cancelado',
      'reservado_recogida' => 'Reservado',
      'reservado_delivery' => 'Reservado delivery',
      'confirmado_negocio' => 'Confirmado',
      'preparando' => 'Preparando',
      'listo_para_recoger' => 'Listo',
      'delivery_asignado' => 'Delivery asignado',
      'recogido_por_delivery' => 'Recogido',
      'en_ruta' => 'En ruta',
      'entregado_por_delivery' => 'Entregado',
      'recibido_cliente' => 'Recibido',
      'vendido_en_tienda' => 'Vendido',
      'completado' => 'Completado',
      _ => status ?? 'Nuevo',
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] is List
        ? json['items'] as List
        : json['orden_items'] is List
        ? json['orden_items'] as List
        : const [];
    final parsedItems = rawItems
        .whereType<Map>()
        .map((item) => OrderItemModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return OrderModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      items: parsedItems,
      productId: json['producto_id']?.toString(),
      propertyId: json['propiedad_id']?.toString(),
      transportId: json['transporte_id']?.toString(),
      type: json['tipo']?.toString(),
      status: json['estado']?.toString(),
      contactName: json['nombre_contacto']?.toString(),
      phone: json['telefono']?.toString(),
      email: json['email']?.toString(),
      message: json['mensaje']?.toString(),
      quantity:
          int.tryParse('${json['cantidad'] ?? ''}') ??
          (parsedItems.isEmpty
              ? null
              : parsedItems.fold<int>(0, (sum, item) => sum + item.quantity)),
      currency: json['moneda']?.toString(),
      estimatedTotal: double.tryParse('${json['total_estimado'] ?? ''}'),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

class OrderItemModel {
  const OrderItemModel({
    required this.name,
    required this.quantity,
    this.productId,
    this.brand,
    this.unitPrice,
    this.subtotal,
    this.currency,
    this.imageUrl,
  });

  final String name;
  final int quantity;
  final String? productId;
  final String? brand;
  final double? unitPrice;
  final double? subtotal;
  final String? currency;
  final String? imageUrl;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      name: '${json['nombre'] ?? json['name'] ?? 'Producto'}',
      quantity:
          int.tryParse('${json['cantidad'] ?? json['quantity'] ?? 1}') ?? 1,
      productId: json['producto_id']?.toString(),
      brand: json['marca']?.toString(),
      unitPrice: double.tryParse('${json['precio_unitario'] ?? ''}'),
      subtotal: double.tryParse('${json['subtotal'] ?? ''}'),
      currency: json['moneda']?.toString(),
      imageUrl: json['imagen_url']?.toString(),
    );
  }
}
