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
    this.connectedBusiness,
    this.notes,
    this.productsOfInterest = const [],
  });

  final String id;
  final String businessId;
  final String connectedBusinessId;
  final bool notifications;
  final String relationType;
  final String status;
  final BusinessModel? connectedBusiness;
  final String? notes;
  final List<String> productsOfInterest;
  final List<ProductModel> products;

  String get relationLabel {
    return switch (relationType) {
      'proveedor' => 'Me provee',
      'cliente_mayorista' => 'Le suministro',
      'delivery' => 'Delivery aliado',
      'aliado' => 'Aliado',
      _ => relationType,
    };
  }

  BusinessConnectionModel copyWith({
    bool? notifications,
    String? status,
    List<ProductModel>? products,
  }) {
    return BusinessConnectionModel(
      id: id,
      businessId: businessId,
      connectedBusinessId: connectedBusinessId,
      notifications: notifications ?? this.notifications,
      relationType: relationType,
      status: status ?? this.status,
      connectedBusiness: connectedBusiness,
      notes: notes,
      productsOfInterest: productsOfInterest,
      products: products ?? this.products,
    );
  }

  factory BusinessConnectionModel.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['productos_actuales'];
    final rawInterest = json['productos_interes'];
    return BusinessConnectionModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? ''}',
      connectedBusinessId: '${json['negocio_suscrito_id'] ?? ''}',
      notifications: json['notificaciones'] != false,
      relationType: '${json['tipo_relacion'] ?? 'proveedor'}',
      status: '${json['estado'] ?? 'activa'}',
      connectedBusiness: json['negocio_conectado'] is Map
          ? BusinessModel.fromJson(
              Map<String, dynamic>.from(json['negocio_conectado'] as Map),
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
    );
  }
}
