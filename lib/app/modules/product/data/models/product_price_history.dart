/// Historico de precios de un producto (venta promedio y compra promedio por dia).
///
/// Corresponde a la respuesta de `GET /productos/{id}/estadisticas-precio`.
class ProductPricePoint {
  const ProductPricePoint({
    required this.fecha,
    this.precioVenta,
    this.precioOferta,
    this.precioCompra,
    this.moneda = 'CUP',
  });

  final String fecha;
  final double? precioVenta;
  final double? precioOferta;
  final double? precioCompra;
  final String moneda;

  String get fechaLabel {
    final parsed = DateTime.tryParse(fecha);
    if (parsed == null) return fecha;
    return '${parsed.day}/${parsed.month}';
  }

  factory ProductPricePoint.fromJson(Map<String, dynamic> json) {
    return ProductPricePoint(
      fecha: '${json['fecha'] ?? ''}',
      precioVenta: double.tryParse('${json['precio'] ?? ''}'),
      precioOferta: double.tryParse('${json['precio_oferta'] ?? ''}'),
      precioCompra: double.tryParse('${json['precio_compra'] ?? ''}'),
      moneda: '${json['moneda'] ?? 'CUP'}',
    );
  }
}

class ProductPriceResumen {
  const ProductPriceResumen({
    this.diasCapturados = 0,
    this.minimo,
    this.maximo,
    this.promedio,
    this.primero,
    this.ultimo,
    this.variacionPorcentual,
    this.costoPromedio,
  });

  final int diasCapturados;
  final double? minimo;
  final double? maximo;
  final double? promedio;
  final double? primero;
  final double? ultimo;
  final double? variacionPorcentual;
  final double? costoPromedio;

  factory ProductPriceResumen.fromJson(dynamic json) {
    if (json is! Map) return const ProductPriceResumen();
    final map = Map<String, dynamic>.from(json);
    return ProductPriceResumen(
      diasCapturados: int.tryParse('${map['dias_capturados'] ?? ''}') ?? 0,
      minimo: double.tryParse('${map['minimo'] ?? ''}'),
      maximo: double.tryParse('${map['maximo'] ?? ''}'),
      promedio: double.tryParse('${map['promedio'] ?? ''}'),
      primero: double.tryParse('${map['primero'] ?? ''}'),
      ultimo: double.tryParse('${map['ultimo'] ?? ''}'),
      variacionPorcentual: double.tryParse(
        '${map['variacion_porcentual'] ?? ''}',
      ),
      costoPromedio: double.tryParse('${map['costo_promedio'] ?? ''}'),
    );
  }
}

class ProductPriceHistory {
  const ProductPriceHistory({
    required this.productoId,
    this.nombre = '',
    this.monedaActual = 'CUP',
    this.ventanaDias = 365,
    this.resumen = const ProductPriceResumen(),
    this.serie = const [],
  });

  final String productoId;
  final String nombre;
  final String monedaActual;
  final int ventanaDias;
  final ProductPriceResumen resumen;
  final List<ProductPricePoint> serie;

  bool get tieneVenta => serie.any((punto) => punto.precioVenta != null);
  bool get tieneCompra => serie.any((punto) => punto.precioCompra != null);

  factory ProductPriceHistory.fromJson(Map<String, dynamic> json) {
    final serie = <ProductPricePoint>[];
    final rawSerie = json['serie'];
    if (rawSerie is List) {
      for (final item in rawSerie) {
        if (item is Map) {
          serie.add(ProductPricePoint.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    serie.sort((a, b) => a.fecha.compareTo(b.fecha));

    return ProductPriceHistory(
      productoId: '${json['producto_id'] ?? ''}',
      nombre: '${json['nombre'] ?? ''}',
      monedaActual: '${json['moneda_actual'] ?? 'CUP'}',
      ventanaDias: int.tryParse('${json['ventana_dias'] ?? ''}') ?? 365,
      resumen: ProductPriceResumen.fromJson(json['resumen']),
      serie: serie,
    );
  }
}