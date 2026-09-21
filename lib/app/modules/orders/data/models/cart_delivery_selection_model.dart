class CartDeliverySelection {
  const CartDeliverySelection({
    required this.deliveryBusinessId,
    required this.deliveryBusinessName,
    required this.source,
    this.assignmentMode = 'manual',
    this.province,
    this.municipality,
    this.deliveryPerfilId,
    this.email,
    this.telefono,
    this.tipoVehiculo,
    this.calificacion,
  });

  final String deliveryBusinessId;
  final String deliveryBusinessName;
  final String source;
  final String assignmentMode;
  final String? province;
  final String? municipality;
  final String? deliveryPerfilId;
  final String? email;
  final String? telefono;
  final String? tipoVehiculo;
  final double? calificacion;

  CartDeliverySelection copyWith({
    String? deliveryBusinessId,
    String? deliveryBusinessName,
    String? source,
    String? assignmentMode,
    String? province,
    String? municipality,
    String? deliveryPerfilId,
    String? email,
    String? telefono,
    String? tipoVehiculo,
    double? calificacion,
  }) {
    return CartDeliverySelection(
      deliveryBusinessId: deliveryBusinessId ?? this.deliveryBusinessId,
      deliveryBusinessName: deliveryBusinessName ?? this.deliveryBusinessName,
      source: source ?? this.source,
      assignmentMode: assignmentMode ?? this.assignmentMode,
      province: province ?? this.province,
      municipality: municipality ?? this.municipality,
      deliveryPerfilId: deliveryPerfilId ?? this.deliveryPerfilId,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      tipoVehiculo: tipoVehiculo ?? this.tipoVehiculo,
      calificacion: calificacion ?? this.calificacion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery_business_id': deliveryBusinessId,
      'delivery_business_name': deliveryBusinessName,
      'source': source,
      'assignment_mode': assignmentMode,
      'province': province,
      'municipality': municipality,
      'delivery_perfil_id': deliveryPerfilId,
      'email': email,
      'telefono': telefono,
      'tipo_vehiculo': tipoVehiculo,
      'calificacion': calificacion,
    };
  }

  factory CartDeliverySelection.fromJson(Map<String, dynamic> json) {
    return CartDeliverySelection(
      deliveryBusinessId: '${json['delivery_business_id'] ?? ''}',
      deliveryBusinessName: '${json['delivery_business_name'] ?? ''}',
      source: '${json['source'] ?? 'sistema'}',
      assignmentMode: '${json['assignment_mode'] ?? 'manual'}',
      province: json['province']?.toString(),
      municipality: json['municipality']?.toString(),
      deliveryPerfilId: json['delivery_perfil_id']?.toString(),
      email: json['email']?.toString(),
      telefono: json['telefono']?.toString(),
      tipoVehiculo: json['tipo_vehiculo']?.toString(),
      calificacion: (json['calificacion'] as num?)?.toDouble(),
    );
  }
}