class DeliveryProfileModel {
  const DeliveryProfileModel({
    required this.id,
    required this.userId,
    this.active = true,
    this.available = false,
    this.vehicleType,
    this.plate,
    this.baseRate = 0,
    this.perKmRate = 0,
    this.operatingRadiusKm = 8,
    this.averageRating,
    this.completedDeliveries = 0,
    this.cancelledDeliveries = 0,
    this.traveledKm = 0,
    this.trustLevel,
  });

  final String id;
  final String userId;
  final bool active;
  final bool available;
  final String? vehicleType;
  final String? plate;
  final double baseRate;
  final double perKmRate;
  final double operatingRadiusKm;
  final double? averageRating;
  final int completedDeliveries;
  final int cancelledDeliveries;
  final double traveledKm;
  final String? trustLevel;

  DeliveryProfileModel copyWith({bool? available}) {
    return DeliveryProfileModel(
      id: id,
      userId: userId,
      active: active,
      available: available ?? this.available,
      vehicleType: vehicleType,
      plate: plate,
      baseRate: baseRate,
      perKmRate: perKmRate,
      operatingRadiusKm: operatingRadiusKm,
      averageRating: averageRating,
      completedDeliveries: completedDeliveries,
      cancelledDeliveries: cancelledDeliveries,
      traveledKm: traveledKm,
      trustLevel: trustLevel,
    );
  }

  factory DeliveryProfileModel.fromJson(Map<String, dynamic> json) {
    return DeliveryProfileModel(
      id: '${json['id'] ?? ''}',
      userId: '${json['usuario_id'] ?? ''}',
      active: json['activo'] != false,
      available: json['disponible'] == true,
      vehicleType: json['tipo_vehiculo']?.toString(),
      plate: json['placa']?.toString(),
      baseRate: _num(json['tarifa_base']),
      perKmRate: _num(json['tarifa_por_km']),
      operatingRadiusKm: _num(json['radio_operacion_km'], fallback: 8),
      averageRating: _nullableNum(json['calificacion_promedio']),
      completedDeliveries: _int(json['entregas_completadas']),
      cancelledDeliveries: _int(json['entregas_canceladas']),
      traveledKm: _num(json['km_recorridos']),
      trustLevel: json['nivel_confianza']?.toString(),
    );
  }

  static double _num(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  static double? _nullableNum(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
