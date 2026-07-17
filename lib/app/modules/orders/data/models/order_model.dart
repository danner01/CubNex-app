import '../../../../config/environment/app_environment.dart';

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
    this.qrCode,
    this.qrUrl,
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
  final String? qrCode;
  final String? qrUrl;
  final DateTime? createdAt;

  bool get hasQr => qrValue != null;

  bool get canShowQrAction {
    if (hasQr) return true;
    return switch (status) {
      'reservado_recogida' ||
      'reservado_delivery' ||
      'solicitada' ||
      'recibida' ||
      'confirmado_negocio' ||
      'preparando' ||
      'listo_para_recoger' ||
      'delivery_asignado' ||
      'recogido_por_delivery' ||
      'en_ruta' ||
      'entregado_por_delivery' ||
      'recibido_cliente' ||
      'vendido_en_tienda' ||
      'completado' => true,
      _ => false,
    };
  }

  String? get qrValue {
    final url = _normalizedQrValue(
      qrUrl ??
          metadata?['qr_url'] ??
          metadata?['qrUrl'] ??
          metadata?['codigo_qr_url'],
    );
    if (url != null) return url;

    final code = _normalizedQrValue(
      qrCode ??
          metadata?['qr_codigo'] ??
          metadata?['qrCode'] ??
          metadata?['token_qr'],
    );
    if (code == null) return null;
    return '${AppEnvironment.apiBaseUrl}/api/v1/ordenes/qr/$code';
  }

  String get title {
    if (items.isNotEmpty) {
      if (items.length == 1) return items.first.name;
      return '${items.length} productos reservados';
    }

    final metadataTitle =
        metadata?['nombre_producto'] ??
        metadata?['producto_nombre'] ??
        metadata?['titulo'] ??
        metadata?['nombre'];
    if (metadataTitle != null && '$metadataTitle'.isNotEmpty) {
      return '$metadataTitle';
    }

    if (type == 'solicitud_red') {
      return 'Solicitud de abastecimiento';
    }

    return switch (type) {
      'producto' => 'Solicitud de producto',
      'propiedad' => 'Solicitud de propiedad',
      'transporte' => 'Solicitud de transporte',
      'servicio' => 'Solicitud de servicio',
      'solicitud_red' => 'Solicitud de red',
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
      'solicitud_red' => 'Red',
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
      'solicitada' => 'Solicitada',
      'recibida' => 'Recibida',
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
      'caducado' => 'Caducado',
      _ => status ?? 'Nuevo',
    };
  }

  bool get supportsReservationExpiry {
    return switch (status) {
      'reservado_recogida' ||
      'reservado_delivery' ||
      'solicitada' ||
      'recibida' ||
      'confirmado_negocio' ||
      'preparando' ||
      'listo_para_recoger' => true,
      _ => false,
    };
  }

  DateTime? get reservationExpiresAt {
    final raw =
        metadata?['reserva_expira_at'] ??
        metadata?['reservaExpiraAt'] ??
        metadata?['reservation_expires_at'];
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return DateTime.tryParse('$raw')?.toLocal();
  }

  Duration? get reservationTimeRemaining {
    final expiresAt = reservationExpiresAt;
    if (expiresAt == null) return null;
    return expiresAt.difference(DateTime.now());
  }

  String? get primaryImageUrl {
    for (final item in items) {
      final value = item.imageUrl?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final metadataImage =
        metadata?['imagen_url'] ??
        metadata?['image_url'] ??
        metadata?['foto_url'] ??
        metadata?['thumbnail_url'];
    if (metadataImage == null) return null;
    final normalized = '$metadataImage'.trim();
    return normalized.isEmpty ? null : normalized;
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
    final sourceBusiness = json['negocio_solicitante'] is Map
        ? Map<String, dynamic>.from(json['negocio_solicitante'] as Map)
        : <String, dynamic>{};
    final targetBusiness = json['negocio_destino'] is Map
        ? Map<String, dynamic>.from(json['negocio_destino'] as Map)
        : <String, dynamic>{};
    final rawMetadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};
    final qrRelation = json['qr'];
    final qrEntry = qrRelation is List && qrRelation.isNotEmpty
        ? qrRelation.first
        : qrRelation;
    final qrMap = qrEntry is Map
        ? Map<String, dynamic>.from(qrEntry)
        : <String, dynamic>{};
    final synthesizedMetadata = <String, dynamic>{
      if (json['nombre_producto'] != null)
        'nombre_producto': json['nombre_producto'],
      if (json['producto_nombre'] != null)
        'producto_nombre': json['producto_nombre'],
      if (json['negocio_solicitante_nombre'] != null)
        'negocio_solicitante_nombre': json['negocio_solicitante_nombre'],
      if (json['negocio_destino_nombre'] != null)
        'negocio_destino_nombre': json['negocio_destino_nombre'],
      if (sourceBusiness['nombre'] != null)
        'negocio_solicitante_nombre': sourceBusiness['nombre'],
      if (targetBusiness['nombre'] != null)
        'negocio_destino_nombre': targetBusiness['nombre'],
      if (json['unidad'] != null) 'unidad': json['unidad'],
      if (json['precio_referencia'] != null)
        'precio_referencia': json['precio_referencia'],
      if (json['cantidad'] != null) 'cantidad': json['cantidad'],
      if (json['qr_url'] != null) 'qr_url': json['qr_url'],
      if (json['qr_codigo'] != null) 'qr_codigo': json['qr_codigo'],
      if (qrMap['token'] != null) 'token_qr': qrMap['token'],
    };
    final mergedMetadata = <String, dynamic>{
      ...rawMetadata,
      ...synthesizedMetadata,
    };

    return OrderModel(
      id: '${json['id'] ?? ''}',
      businessId:
          '${json['negocio_id'] ?? json['negocio_destino_id'] ?? json['negocio_solicitante_id'] ?? ''}',
      items: parsedItems,
      productId: json['producto_id']?.toString(),
      propertyId: json['propiedad_id']?.toString(),
      transportId: json['transporte_id']?.toString(),
      type:
          json['tipo']?.toString() ??
          (json['negocio_solicitante_id'] != null &&
                  json['negocio_destino_id'] != null
              ? 'solicitud_red'
              : null),
      status: json['estado']?.toString(),
      contactName:
          json['nombre_contacto']?.toString() ??
          json['negocio_solicitante_nombre']?.toString() ??
          sourceBusiness['nombre']?.toString(),
      phone: json['telefono']?.toString(),
      email: json['email']?.toString(),
      message: json['mensaje']?.toString(),
      quantity:
          int.tryParse('${json['cantidad'] ?? ''}') ??
          (parsedItems.isEmpty
              ? null
              : parsedItems.fold<int>(0, (sum, item) => sum + item.quantity)),
      currency: json['moneda']?.toString(),
      estimatedTotal: double.tryParse(
        '${json['total_estimado'] ?? json['precio_referencia'] ?? ''}',
      ),
      metadata: mergedMetadata.isEmpty ? null : mergedMetadata,
      qrCode: _normalizedQrValue(
        json['qr_codigo'] ?? json['qrCode'] ?? qrMap['token'],
      ),
      qrUrl: _normalizedQrValue(
        json['qr_url'] ?? json['qrUrl'] ?? qrMap['qr_url'] ?? qrMap['data_url'],
      ),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  static String? _normalizedQrValue(Object? value) {
    if (value == null) return null;
    final normalized = '$value'.trim();
    return normalized.isEmpty ? null : normalized;
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
