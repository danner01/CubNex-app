class CartDeliverySelection {
  const CartDeliverySelection({
    required this.deliveryBusinessId,
    required this.deliveryBusinessName,
    required this.source,
    this.assignmentMode = 'manual',
    this.province,
    this.municipality,
  });

  final String deliveryBusinessId;
  final String deliveryBusinessName;
  final String source;
  final String assignmentMode;
  final String? province;
  final String? municipality;

  CartDeliverySelection copyWith({
    String? deliveryBusinessId,
    String? deliveryBusinessName,
    String? source,
    String? assignmentMode,
    String? province,
    String? municipality,
  }) {
    return CartDeliverySelection(
      deliveryBusinessId: deliveryBusinessId ?? this.deliveryBusinessId,
      deliveryBusinessName: deliveryBusinessName ?? this.deliveryBusinessName,
      source: source ?? this.source,
      assignmentMode: assignmentMode ?? this.assignmentMode,
      province: province ?? this.province,
      municipality: municipality ?? this.municipality,
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
    );
  }
}
