class BusinessProductCost {
  const BusinessProductCost({
    required this.productoId,
    this.costo,
    this.costoMoneda,
    this.tieneCosto = false,
    this.margenPct,
    this.margenNominalPct,
    this.precioCup,
    this.costoCup,
    this.utilidadCup,
    this.tasaUsd,
    this.costoActualizadoEn,
    this.margenBasePct,
    this.variacionMargenPct,
  });

  final String productoId;
  final double? costo;
  final String? costoMoneda;
  final bool tieneCosto;
  final double? margenPct;
  final double? margenNominalPct;
  final double? precioCup;
  final double? costoCup;
  final double? utilidadCup;
  final double? tasaUsd;
  final String? costoActualizadoEn;
  final double? margenBasePct;
  final double? variacionMargenPct;

  factory BusinessProductCost.fromJson(Map<String, dynamic> json) {
    return BusinessProductCost(
      productoId: '${json['producto_id'] ?? ''}',
      costo: double.tryParse('${json['costo'] ?? ''}'),
      costoMoneda: json['costo_moneda']?.toString(),
      tieneCosto: json['tiene_costo'] == true,
      margenPct: double.tryParse('${json['margen_pct'] ?? ''}'),
      margenNominalPct: double.tryParse('${json['margen_nominal_pct'] ?? ''}'),
      precioCup: double.tryParse('${json['precio_cup'] ?? ''}'),
      costoCup: double.tryParse('${json['costo_cup'] ?? ''}'),
      utilidadCup: double.tryParse('${json['utilidad_cup'] ?? ''}'),
      tasaUsd: double.tryParse('${json['tasa_usd'] ?? ''}'),
      costoActualizadoEn: json['costo_actualizado_en']?.toString(),
      margenBasePct: double.tryParse('${json['margen_base_pct'] ?? ''}'),
      variacionMargenPct: double.tryParse(
        '${json['variacion_margen_pct'] ?? ''}',
      ),
    );
  }
}

class BusinessProfitabilityPoint {
  const BusinessProfitabilityPoint({
    required this.fecha,
    this.precioCup,
    this.costoCup,
    this.margenNominalPct,
    this.margenIndexadoPct,
    this.tasaUsd,
  });

  final String fecha;
  final double? precioCup;
  final double? costoCup;
  final double? margenNominalPct;
  final double? margenIndexadoPct;
  final double? tasaUsd;

  factory BusinessProfitabilityPoint.fromJson(Map<String, dynamic> json) {
    return BusinessProfitabilityPoint(
      fecha: '${json['fecha'] ?? ''}',
      precioCup: double.tryParse('${json['precio_cup'] ?? ''}'),
      costoCup: double.tryParse('${json['costo_cup'] ?? ''}'),
      margenNominalPct: double.tryParse('${json['margen_nominal_pct'] ?? ''}'),
      margenIndexadoPct: double.tryParse('${json['margen_indexado_pct'] ?? ''}'),
      tasaUsd: double.tryParse('${json['tasa_usd'] ?? ''}'),
    );
  }
}

class BusinessProductProfitability {
  const BusinessProductProfitability({
    required this.productoId,
    this.nombre,
    this.precio,
    this.moneda,
    this.costo,
    this.costoMoneda,
    this.tieneCosto = false,
    this.ventanaDias = 90,
    this.serie = const [],
    this.margenActualPct,
    this.margenNominalActualPct,
    this.mejorMargenPct,
    this.peorMargenPct,
    this.precioCup,
    this.costoCup,
  });

  final String productoId;
  final String? nombre;
  final double? precio;
  final String? moneda;
  final double? costo;
  final String? costoMoneda;
  final bool tieneCosto;
  final int ventanaDias;
  final List<BusinessProfitabilityPoint> serie;
  final double? margenActualPct;
  final double? margenNominalActualPct;
  final double? mejorMargenPct;
  final double? peorMargenPct;
  final double? precioCup;
  final double? costoCup;

  factory BusinessProductProfitability.fromJson(Map<String, dynamic> json) {
    final serie = <BusinessProfitabilityPoint>[];
    final rawSerie = json['serie'];
    if (rawSerie is List) {
      for (final item in rawSerie) {
        if (item is Map) {
          serie.add(
            BusinessProfitabilityPoint.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final resumen = json['resumen'];
    final resumenMap = resumen is Map
        ? Map<String, dynamic>.from(resumen)
        : const <String, dynamic>{};

    return BusinessProductProfitability(
      productoId: '${json['producto_id'] ?? ''}',
      nombre: json['nombre']?.toString(),
      precio: double.tryParse('${json['precio'] ?? ''}'),
      moneda: json['moneda']?.toString(),
      costo: double.tryParse('${json['costo'] ?? ''}'),
      costoMoneda: json['costo_moneda']?.toString(),
      tieneCosto: json['tiene_costo'] == true,
      ventanaDias: int.tryParse('${json['ventana_dias'] ?? ''}') ?? 90,
      serie: serie,
      margenActualPct: double.tryParse(
        '${resumenMap['margen_actual_pct'] ?? ''}',
      ),
      margenNominalActualPct: double.tryParse(
        '${resumenMap['margen_nominal_actual_pct'] ?? ''}',
      ),
      mejorMargenPct: double.tryParse('${resumenMap['mejor_margen_pct'] ?? ''}'),
      peorMargenPct: double.tryParse('${resumenMap['peor_margen_pct'] ?? ''}'),
      precioCup: double.tryParse('${resumenMap['precio_cup'] ?? ''}'),
      costoCup: double.tryParse('${resumenMap['costo_cup'] ?? ''}'),
    );
  }
}
