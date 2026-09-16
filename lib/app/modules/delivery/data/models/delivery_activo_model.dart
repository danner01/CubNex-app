class DeliveryActivoModel {
  const DeliveryActivoModel({
    required this.id,
    this.nombre,
    this.tipoVehiculo,
    this.placa,
    this.tarifaBase = 0,
    this.tarifaPorKm = 0,
    this.radioOperacionKm = 8,
    this.calificacionPromedio = 0,
    this.entregasCompletadas = 0,
    this.nivelConfianza = 'nuevo',
    this.distanciaKm = 0,
    this.ultimaUbicacion,
    this.avatarUrl,
    this.colorMarcador,
  });

  factory DeliveryActivoModel.fromJson(Map<String, dynamic> json) {
    return DeliveryActivoModel(
      id: '${json['id'] ?? ''}',
      nombre: json['nombre']?.toString(),
      tipoVehiculo: json['tipo_vehiculo']?.toString(),
      placa: json['placa']?.toString(),
      tarifaBase: _num(json['tarifa_base']) ?? 0,
      tarifaPorKm: _num(json['tarifa_por_km']) ?? 0,
      radioOperacionKm: _num(json['radio_operacion_km']) ?? 8,
      calificacionPromedio: _num(json['calificacion_promedio']) ?? 0,
      entregasCompletadas: _int(json['entregas_completadas']) ?? 0,
      nivelConfianza: json['nivel_confianza']?.toString() ?? 'nuevo',
      distanciaKm: _num(json['distancia_km']) ?? 0,
      ultimaUbicacion: json['ultima_ubicacion'] is Map
          ? DeliveryActivoUbicacion.fromJson(
              Map<String, dynamic>.from(json['ultima_ubicacion'] as Map),
            )
          : null,
      avatarUrl: json['avatar_url']?.toString(),
      colorMarcador: json['color_marcador']?.toString(),
    );
  }

  final String id;
  final String? nombre;
  final String? tipoVehiculo;
  final String? placa;
  final double tarifaBase;
  final double tarifaPorKm;
  final double radioOperacionKm;
  final double calificacionPromedio;
  final int entregasCompletadas;
  final String nivelConfianza;
  final double distanciaKm;
  final DeliveryActivoUbicacion? ultimaUbicacion;
  final String? avatarUrl;
  final String? colorMarcador;
}

class DeliveryActivoUbicacion {
  const DeliveryActivoUbicacion({
    this.lat,
    this.lng,
    this.precisionMetros,
    this.velocidadKmh,
    this.rumbo,
    this.createdAt,
  });

  factory DeliveryActivoUbicacion.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordenadas'];
    final coords = coordinates is Map
        ? Map<String, dynamic>.from(coordinates)
        : const <String, dynamic>{};
    return DeliveryActivoUbicacion(
      lat: _num(coords['lat']) ?? _num(coords['latitude']) ?? _num(coords['y']),
      lng:
          _num(coords['lng']) ??
          _num(coords['lon']) ??
          _num(coords['longitude']) ??
          _num(coords['x']),
      precisionMetros: _num(json['precision_metros']),
      velocidadKmh: _num(json['velocidad_kmh']),
      rumbo: _num(json['rumbo']),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  final double? lat;
  final double? lng;
  final double? precisionMetros;
  final double? velocidadKmh;
  final double? rumbo;
  final DateTime? createdAt;
}

double? _num(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? _int(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}
