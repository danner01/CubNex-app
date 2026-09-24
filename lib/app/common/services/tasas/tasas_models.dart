class TasaReferencia {
  const TasaReferencia({
    required this.codigo,
    required this.nombre,
    this.cup,
    this.compra,
    this.venta,
    required this.fuente,
  });

  final String codigo;
  final String nombre;
  final double? cup;
  final double? compra;
  final double? venta;
  final String fuente;

  factory TasaReferencia.fromJson(Map<String, dynamic> json) {
    return TasaReferencia(
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      cup: _num(json['cup']),
      compra: _num(json['compra']),
      venta: _num(json['venta']),
      fuente: json['fuente']?.toString() ?? '',
    );
  }
}

class TasaValor {
  const TasaValor({this.compra, this.venta});

  final double? compra;
  final double? venta;

  factory TasaValor.fromJson(Map<String, dynamic> json) {
    return TasaValor(
      compra: _num(json['compra']),
      venta: _num(json['venta']),
    );
  }
}

class TasasMercado {
  const TasasMercado({
    required this.tasas,
    required this.oficial,
    required this.fuente,
    this.actualizadoEn,
    this.fecha,
  });

  final Map<String, TasaReferencia> tasas;
  final Map<String, TasaValor> oficial;
  final String fuente;
  final String? actualizadoEn;
  final String? fecha;
}

class TasaHistorialPunto {
  const TasaHistorialPunto({
    required this.fecha,
    this.cup,
    required this.fuente,
    required this.moneda,
  });

  final String fecha;
  final double? cup;
  final String fuente;
  final String moneda;

  factory TasaHistorialPunto.fromJson(Map<String, dynamic> json) {
    return TasaHistorialPunto(
      fecha: json['fecha']?.toString() ?? '',
      cup: _num(json['cup']),
      fuente: json['fuente']?.toString() ?? '',
      moneda: json['moneda']?.toString() ?? '',
    );
  }
}

double? _num(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}