import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';

class BusinessConnectionModel {
  const BusinessConnectionModel({
    required this.id,
    required this.businessId,
    required this.connectedBusinessId,
    required this.notifications,
    required this.relationType,
    required this.status,
    required this.products,
    required this.relationDirection,
    this.connectedBusiness,
    this.notes,
    this.productsOfInterest = const [],
    this.requests = const [],
  });

  final String id;
  final String businessId;
  final String connectedBusinessId;
  final bool notifications;
  final String relationType;
  final String status;
  final String relationDirection;
  final BusinessModel? connectedBusiness;
  final String? notes;
  final List<String> productsOfInterest;
  final List<ProductModel> products;
  final List<BusinessConnectionRequestModel> requests;

  String get relationLabel {
    return switch (relationType) {
      'proveedor' => 'Me provee',
      'cliente_mayorista' => 'Le suministro',
      'delivery' => 'Delivery aliado',
      'aliado' => 'Aliado',
      _ => relationType,
    };
  }

  bool get isPending =>
      status == 'solicitada' || status == 'pendiente' || status == 'incompleta';

  bool get isActive =>
      status == 'activa' || status == 'aceptada' || status == 'confirmada';

  bool get isIncomingRequest => relationDirection == 'entrante';

  String get statusLabel {
    if (isActive) return 'Conexion activa';
    if (isPending && isIncomingRequest) return 'Solicitud pendiente';
    if (isPending) return 'Esperando respuesta';
    return status;
  }

  BusinessConnectionModel copyWith({
    String? id,
    String? businessId,
    String? connectedBusinessId,
    bool? notifications,
    String? relationType,
    String? status,
    String? relationDirection,
    BusinessModel? connectedBusiness,
    String? notes,
    List<String>? productsOfInterest,
    List<ProductModel>? products,
    List<BusinessConnectionRequestModel>? requests,
  }) {
    return BusinessConnectionModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      connectedBusinessId: connectedBusinessId ?? this.connectedBusinessId,
      notifications: notifications ?? this.notifications,
      relationType: relationType ?? this.relationType,
      status: status ?? this.status,
      relationDirection: relationDirection ?? this.relationDirection,
      connectedBusiness: connectedBusiness ?? this.connectedBusiness,
      notes: notes ?? this.notes,
      productsOfInterest: productsOfInterest ?? this.productsOfInterest,
      products: products ?? this.products,
      requests: requests ?? this.requests,
    );
  }

  factory BusinessConnectionModel.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['productos_actuales'];
    final rawInterest = json['productos_interes'];
    final rawRequests = json['solicitudes'];
    final rawConnectedBusiness =
        json['negocio_conectado'] ?? json['negocio_origen'];
    final rawDirection = json['direccion_relacion'];
    final connectedBusinessId =
        json['negocio_suscrito_id'] ??
        json['negocio_conectado_id'] ??
        json['negocio_origen_id'] ??
        (rawConnectedBusiness is Map ? rawConnectedBusiness['id'] : null);
    return BusinessConnectionModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      connectedBusinessId: '${connectedBusinessId ?? ''}',
      notifications: json['notificaciones'] != false,
      relationType: '${json['tipo_relacion'] ?? 'proveedor'}',
      status: '${json['estado'] ?? 'activa'}',
      relationDirection: '${rawDirection ?? 'saliente'}',
      connectedBusiness: rawConnectedBusiness is Map
          ? BusinessModel.fromJson(
              Map<String, dynamic>.from(rawConnectedBusiness),
            )
          : null,
      notes: json['notas']?.toString(),
      productsOfInterest: rawInterest is List
          ? rawInterest.map((item) => '$item').toList()
          : const [],
      products: rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map(
                  (item) =>
                      ProductModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      requests: rawRequests is List
          ? rawRequests
                .whereType<Map>()
                .map(
                  (item) => BusinessConnectionRequestModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class BusinessConnectionRequestModel {
  const BusinessConnectionRequestModel({
    required this.id,
    required this.connectionId,
    required this.requesterBusinessId,
    required this.targetBusinessId,
    required this.productName,
    this.status,
    this.quantity,
    this.unit,
    this.message,
    this.currency,
    this.referencePrice,
    this.createdAt,
  });

  final String id;
  final String connectionId;
  final String requesterBusinessId;
  final String targetBusinessId;
  final String productName;
  final String? status;
  final double? quantity;
  final String? unit;
  final String? message;
  final String? currency;
  final double? referencePrice;
  final DateTime? createdAt;

  String get statusLabel {
    return switch (status) {
      'solicitada' => 'Solicitada',
      'vista' => 'Vista',
      'aceptada' => 'Aceptada',
      'rechazada' => 'Rechazada',
      'completada' => 'Completada',
      'cancelada' => 'Cancelada',
      _ => status ?? 'Solicitada',
    };
  }

  factory BusinessConnectionRequestModel.fromJson(Map<String, dynamic> json) {
    return BusinessConnectionRequestModel(
      id: '${json['id'] ?? ''}',
      connectionId: '${json['conexion_id'] ?? ''}',
      requesterBusinessId: '${json['negocio_solicitante_id'] ?? ''}',
      targetBusinessId: '${json['negocio_destino_id'] ?? ''}',
      productName: '${json['nombre_producto'] ?? 'Producto'}',
      status: json['estado']?.toString(),
      quantity: double.tryParse('${json['cantidad'] ?? ''}'),
      unit: json['unidad']?.toString(),
      message: json['mensaje']?.toString(),
      currency: json['moneda']?.toString(),
      referencePrice: double.tryParse('${json['precio_referencia'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
