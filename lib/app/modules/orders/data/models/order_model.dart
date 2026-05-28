class OrderModel {
  const OrderModel({
    required this.id,
    required this.businessId,
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
    final metadataTitle = metadata?['producto_nombre'] ??
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
      _ => status ?? 'Nuevo',
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      productId: json['producto_id']?.toString(),
      propertyId: json['propiedad_id']?.toString(),
      transportId: json['transporte_id']?.toString(),
      type: json['tipo']?.toString(),
      status: json['estado']?.toString(),
      contactName: json['nombre_contacto']?.toString(),
      phone: json['telefono']?.toString(),
      email: json['email']?.toString(),
      message: json['mensaje']?.toString(),
      quantity: int.tryParse('${json['cantidad'] ?? ''}'),
      currency: json['moneda']?.toString(),
      estimatedTotal: double.tryParse('${json['total_estimado'] ?? ''}'),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
