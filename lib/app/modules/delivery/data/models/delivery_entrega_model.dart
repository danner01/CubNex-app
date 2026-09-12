class DeliveryEntregaModel {
  const DeliveryEntregaModel({
    required this.id,
    this.ordenId,
    this.paqueteId,
    this.negocioId,
    this.clienteId,
    this.estado,
    this.negocioNombre,
    this.negocioDireccion,
    this.negocioLatitude,
    this.negocioLongitude,
    this.clienteNombre,
    this.clienteTelefono,
    this.clienteDireccionEntrega,
    this.moneda,
    this.totalEstimado,
    this.montoACobrar,
    this.requiereRetornoDinero = false,
    this.distanciaAlOrigenKm,
    this.distanciaTotalKm,
    this.tarifaEstimada,
    this.tarifaBase = 0,
    this.tarifaPorKm = 0,
    this.creadaEn,
    this.ruta,
  });

  final String id;
  final String? ordenId;
  final String? paqueteId;
  final String? negocioId;
  final String? clienteId;
  final String? estado;
  final String? negocioNombre;
  final String? negocioDireccion;
  final double? negocioLatitude;
  final double? negocioLongitude;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? clienteDireccionEntrega;
  final String? moneda;
  final double? totalEstimado;
  final double? montoACobrar;
  final bool requiereRetornoDinero;
  final double? distanciaAlOrigenKm;
  final double? distanciaTotalKm;
  final double? tarifaEstimada;
  final double tarifaBase;
  final double tarifaPorKm;
  final DateTime? creadaEn;
  final Map<String, dynamic>? ruta;

  List<List<double>>? get rutaCoordenadas {
    final geometry = ruta?['geometry'];
    if (geometry is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.isEmpty) return null;
    final result = <List<double>>[];
    for (final entry in coords) {
      if (entry is! List || entry.length < 2) continue;
      final lng = double.tryParse('${entry[0]}');
      final lat = double.tryParse('${entry[1]}');
      if (lng == null || lat == null) continue;
      result.add([lng, lat]);
    }
    return result.isEmpty ? null : result;
  }

  factory DeliveryEntregaModel.fromJson(Map<String, dynamic> json) {
    final negocio = json['negocio'] is Map
        ? Map<String, dynamic>.from(json['negocio'] as Map)
        : const <String, dynamic>{};
    final cliente = json['cliente'] is Map
        ? Map<String, dynamic>.from(json['cliente'] as Map)
        : const <String, dynamic>{};
    final rutaRaw = json['ruta'];
    final ruta = rutaRaw is Map ? Map<String, dynamic>.from(rutaRaw) : null;

    return DeliveryEntregaModel(
      id: '${json['id'] ?? ''}',
      ordenId: json['orden_id']?.toString(),
      paqueteId: json['paquete_id']?.toString(),
      negocioId: json['negocio_id']?.toString(),
      clienteId: json['cliente_id']?.toString(),
      estado: json['estado']?.toString(),
      negocioNombre:
          negocio['nombre']?.toString() ?? (json['negocio_nombre']?.toString()),
      negocioDireccion:
          negocio['direccion']?.toString() ??
          (json['negocio_direccion']?.toString()),
      negocioLatitude: _coord(
        negocio.isEmpty ? json['origen'] : negocio['coordenadas'],
        lat: true,
      ),
      negocioLongitude: _coord(
        negocio.isEmpty ? json['origen'] : negocio['coordenadas'],
        lat: false,
      ),
      clienteNombre:
          cliente['nombre_contacto']?.toString() ??
          (json['cliente_nombre']?.toString()),
      clienteTelefono:
          cliente['telefono']?.toString() ??
          (json['cliente_telefono']?.toString()),
      clienteDireccionEntrega:
          cliente['direccion_entrega']?.toString() ??
          (json['cliente_direccion_entrega']?.toString()),
      moneda: json['moneda']?.toString() ?? 'CUP',
      totalEstimado: _num(json['total_estimado']),
      montoACobrar: _num(json['monto_a_cobrar']),
      requiereRetornoDinero: json['requiere_retorno_dinero'] == true,
      distanciaAlOrigenKm: _num(json['distancia_al_origen_km']),
      distanciaTotalKm: _num(json['distancia_total_km']),
      tarifaEstimada: _num(json['tarifa_estimada']),
      tarifaBase: _num(json['tarifa_base']) ?? 0,
      tarifaPorKm: _num(json['tarifa_por_km']) ?? 0,
      creadaEn: DateTime.tryParse('${json['created_at'] ?? ''}'),
      ruta: ruta,
    );
  }

  static double? _coord(Object? value, {required bool lat}) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final key = lat ? 'lat' : 'lng';
    final alt = lat
        ? const ['latitude', 'y', 'lat']
        : const ['lon', 'longitude', 'x', 'lng'];
    var raw = map[key];
    if (raw == null) {
      for (final candidate in alt) {
        if (map[candidate] != null) {
          raw = map[candidate];
          break;
        }
      }
    }
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw');
  }

  static double? _num(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
