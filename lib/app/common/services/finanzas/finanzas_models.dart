class PuntoPrecioFinanzas {
  const PuntoPrecioFinanzas({required this.fecha, required this.precioCup});

  final String fecha;
  final double precioCup;

  factory PuntoPrecioFinanzas.fromJson(Map<String, dynamic> json) {
    return PuntoPrecioFinanzas(
      fecha: json['fecha']?.toString() ?? '',
      precioCup: _num(json['precio_cup']) ?? 0,
    );
  }
}

class AlertaPrecioFinanzas {
  const AlertaPrecioFinanzas({
    required this.ambito,
    required this.tipo,
    required this.porcentajeUmbral,
    required this.variacionPorcentual,
  });

  final String ambito;
  final String tipo;
  final double porcentajeUmbral;
  final double variacionPorcentual;

  bool get esIncremento => tipo == 'incremento';

  factory AlertaPrecioFinanzas.fromJson(Map<String, dynamic> json) {
    return AlertaPrecioFinanzas(
      ambito: json['ambito']?.toString() ?? 'global',
      tipo: json['tipo']?.toString() ?? 'incremento',
      porcentajeUmbral: _num(json['porcentaje_umbral']) ?? 0,
      variacionPorcentual: _num(json['variacion_porcentual']) ?? 0,
    );
  }
}

class ProductoFinanzas {
  const ProductoFinanzas({
    required this.id,
    required this.nombre,
    this.marca,
    this.precio,
    this.precioOferta,
    required this.moneda,
    this.precioCup,
    this.tendenciaPorcentual,
    this.serie = const <PuntoPrecioFinanzas>[],
    this.alerta,
  });

  final String id;
  final String nombre;
  final String? marca;
  final double? precio;
  final double? precioOferta;
  final String moneda;
  final double? precioCup;
  final double? tendenciaPorcentual;
  final List<PuntoPrecioFinanzas> serie;
  final AlertaPrecioFinanzas? alerta;

  double get precioEfectivo => precioOferta ?? precio ?? 0;

  String get descripcion {
    final marca = this.marca?.trim() ?? '';
    final nombre = this.nombre.trim();
    if (marca.isEmpty || marca.toLowerCase() == nombre.toLowerCase()) return nombre;
    return '$marca $nombre';
  }

  factory ProductoFinanzas.fromJson(Map<String, dynamic> json) {
    return ProductoFinanzas(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      marca: json['marca']?.toString(),
      precio: _num(json['precio']),
      precioOferta: _num(json['precio_oferta']),
      moneda: json['moneda']?.toString() ?? 'CUP',
      precioCup: _num(json['precio_cup']),
      tendenciaPorcentual: _num(json['tendencia_porcentual']),
      serie: _listaSerie(json['serie']),
      alerta: json['alerta'] is Map
          ? AlertaPrecioFinanzas.fromJson(
              Map<String, dynamic>.from(json['alerta'] as Map),
            )
          : null,
    );
  }
}

class CategoriaFinanzas {
  const CategoriaFinanzas({
    required this.slug,
    required this.nombre,
    required this.totalProductos,
    required this.negocios,
    this.promedioCup,
    this.tendenciaPorcentual,
    this.curada = false,
    this.alerta,
    this.productos = const <ProductoFinanzas>[],
  });

  final String slug;
  final String nombre;
  final int totalProductos;
  final int negocios;
  final double? promedioCup;
  final double? tendenciaPorcentual;
  final bool curada;
  final AlertaPrecioFinanzas? alerta;
  final List<ProductoFinanzas> productos;

  factory CategoriaFinanzas.fromJson(Map<String, dynamic> json) {
    final rawProductos = json['productos'];
    return CategoriaFinanzas(
      slug: json['slug']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      totalProductos: (json['total_productos'] is num)
          ? (json['total_productos'] as num).toInt()
          : 0,
      negocios: (json['negocios'] is num) ? (json['negocios'] as num).toInt() : 0,
      promedioCup: _num(json['promedio_cup']),
      tendenciaPorcentual: _num(json['tendencia_porcentual']),
      curada: json['curada'] == true,
      alerta: json['alerta'] is Map
          ? AlertaPrecioFinanzas.fromJson(
              Map<String, dynamic>.from(json['alerta'] as Map),
            )
          : null,
      productos: rawProductos is List
          ? rawProductos
              .whereType<Map>()
              .map(
                (item) => ProductoFinanzas.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <ProductoFinanzas>[],
    );
  }
}

class FinanzasProductos {
  const FinanzasProductos({
    this.generadoEn,
    required this.conversionCup,
    required this.monedaBase,
    this.totalCategorias = 0,
    this.curado = false,
    this.alertasActivas = 0,
    this.monedasVisibles = const <String>[],
    this.categorias = const <CategoriaFinanzas>[],
  });

  final String? generadoEn;
  final bool conversionCup;
  final String monedaBase;
  final int totalCategorias;
  final bool curado;
  final int alertasActivas;
  final List<String> monedasVisibles;
  final List<CategoriaFinanzas> categorias;

  static const vacio = FinanzasProductos(
    conversionCup: false,
    monedaBase: 'CUP',
  );

  factory FinanzasProductos.fromJson(Map<String, dynamic> json) {
    final rawCategorias = json['categorias'];
    final rawMonedas = json['monedas_visibles'];
    return FinanzasProductos(
      generadoEn: json['generado_en']?.toString(),
      conversionCup: json['conversion_cup'] == true,
      monedaBase: json['moneda_base']?.toString() ?? 'CUP',
      totalCategorias: (json['total_categorias'] is num)
          ? (json['total_categorias'] as num).toInt()
          : 0,
      curado: json['curado'] == true,
      alertasActivas: (json['alertas_activas'] is num)
          ? (json['alertas_activas'] as num).toInt()
          : 0,
      monedasVisibles: rawMonedas is List
          ? rawMonedas
              .whereType<String>()
              .map((moneda) => moneda.trim().toUpperCase())
              .where((moneda) => moneda.isNotEmpty)
              .toList()
          : const <String>[],
      categorias: rawCategorias is List
          ? rawCategorias
              .whereType<Map>()
              .map(
                (item) => CategoriaFinanzas.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <CategoriaFinanzas>[],
    );
  }
}

class TickerMoneda {
  const TickerMoneda({
    required this.codigo,
    this.valor,
    this.tendencia,
  });

  final String codigo;
  final double? valor;
  final double? tendencia;
}

List<PuntoPrecioFinanzas> _listaSerie(Object? raw) {
  if (raw is! List) return const <PuntoPrecioFinanzas>[];
  return raw
      .whereType<Map>()
      .map((item) => PuntoPrecioFinanzas.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

double? _num(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}