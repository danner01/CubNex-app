import '../../../product/data/models/product_price_history.dart';

/// Historico de precios de un servicio (menu_items, transporte, propiedades o
/// combustibles). La serie principal se mapea a [ProductPricePoint.precioVenta]
/// y la serie secundaria (p. ej. precio/km) a [ProductPricePoint.precioCompra]
/// para reutilizar [ProductPriceHistoryChart].
///
/// Corresponde a la respuesta de
/// `GET /servicios/{coleccion}/{item_id}/precio-historico`.
class ServicePriceHistory {
  const ServicePriceHistory({
    required this.itemId,
    this.nombre = '',
    this.monedaActual = 'CUP',
    this.ventanaDias = 365,
    this.resumen = const ProductPriceResumen(),
    this.serie = const [],
  });

  final String itemId;
  final String nombre;
  final String monedaActual;
  final int ventanaDias;
  final ProductPriceResumen resumen;
  final List<ProductPricePoint> serie;

  bool get tieneSerie => serie.any((punto) => punto.precioVenta != null);
  bool get tieneSecundaria => serie.any((punto) => punto.precioCompra != null);

  factory ServicePriceHistory.fromJson(Map<String, dynamic> json) {
    final serie = <ProductPricePoint>[];
    final rawSerie = json['serie'];
    if (rawSerie is List) {
      for (final item in rawSerie) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        serie.add(
          ProductPricePoint(
            fecha: '${map['fecha'] ?? ''}',
            precioVenta: double.tryParse('${map['precio'] ?? ''}'),
            precioCompra: double.tryParse(
              '${map['precio_secundario'] ?? ''}',
            ),
            moneda: '${map['moneda'] ?? 'CUP'}',
          ),
        );
      }
    }
    serie.sort((a, b) => a.fecha.compareTo(b.fecha));

    return ServicePriceHistory(
      itemId: '${json['item_id'] ?? ''}',
      nombre: '${json['nombre'] ?? ''}',
      monedaActual: '${json['moneda_actual'] ?? 'CUP'}',
      ventanaDias: int.tryParse('${json['ventana_dias'] ?? ''}') ?? 365,
      resumen: ProductPriceResumen.fromJson(json['resumen']),
      serie: serie,
    );
  }
}