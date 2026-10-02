import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/services/finanzas/finanzas_formatos.dart';
import '../../../../common/services/finanzas/finanzas_models.dart';
import '../../../../common/services/finanzas/finanzas_service.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';

String _detalleUri(String tipo, String ref, String nombre) {
  return Uri(
    path: AppRoutes.finanzasDetalle,
    queryParameters: {'tipo': tipo, 'ref': ref, 'nombre': nombre},
  ).toString();
}

const _subida = Color(0xFF2ECC71);
const _bajada = Color(0xFFE74C3C);

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  final FinanzasService _finanzas = sl<FinanzasService>();
  bool _cargando = true;
  String? _error;
  TickerSnapshot? _ticker;
  FinanzasProductos? _productos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool refresh = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        _finanzas.obtenerTicker(force: refresh),
        _finanzas.obtenerProductos(),
      ]);
      if (!mounted) return;
      setState(() {
        _ticker = resultados[0] as TickerSnapshot;
        _productos = resultados[1] as FinanzasProductos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los datos de Finanzas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _cargar(refresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.list(
              children: [
                _EncabezadoFinanzas(actualizadoEn: _ticker?.referencia.actualizadoEn),
                const SizedBox(height: 14),
                const _SeccionFinanzas(titulo: 'Mercado'),
                const SizedBox(height: 8),
                if (_cargando)
                  const _CargandoFinanzas()
                else
                  ..._seccionMercado(),
                const SizedBox(height: 18),
                const _SeccionFinanzas(titulo: 'Productos'),
                const SizedBox(height: 8),
                if (_cargando)
                  const _CargandoFinanzas()
                else
                  ..._seccionProductos(),
                if (!_cargando && _error != null) ...[
                  const SizedBox(height: 14),
                  _MensajeFinanzas(texto: _error!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _seccionMercado() {
    final referencia = _ticker?.referencia;
    if (referencia == null || referencia.tasas.isEmpty) {
      return const [_MensajeFinanzas(texto: 'Cotizaciones no disponibles.')];
    }

    final tendencias = <String, double?>{};
    for (final moneda in _ticker?.monedas ?? const <TickerMoneda>[]) {
      tendencias[moneda.codigo] = moneda.tendencia;
    }

    final monedas = referencia.tasas.entries.toList()
      ..sort((a, b) {
        const orden = ['USD', 'EUR', 'MLC', 'USDT'];
        final ia = orden.indexOf(a.key.toUpperCase());
        final ib = orden.indexOf(b.key.toUpperCase());
        return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
      });

    final filas = <Widget>[];
    for (final entry in monedas) {
      final tasa = entry.value;
      final valor = tasa.cup ?? tasa.venta ?? tasa.compra;
      filas.add(
        _MonedaFila(
          codigo: monedaAbreviada(entry.key),
          nombre: tasa.nombre,
          valor: valor,
          tendencia: tendencias[entry.key],
          desglose: '"${tasa.fuente.isEmpty ? 'mercado' : tasa.fuente}"',
          onTap: () => context.go(
            _detalleUri('moneda', entry.key, tasa.nombre),
          ),
        ),
      );
    }

    final oficial = referencia.oficial;
    if (oficial.isNotEmpty) {
      for (final entry in oficial.entries) {
        final tasaLibre = referencia.tasas[entry.key];
        final valor = entry.value.venta ?? entry.value.compra;
        filas.add(
          _MonedaFila(
            codigo: monedaAbreviada(entry.key),
            nombre: 'Tasa oficial',
            valor: valor,
            tendencia: tendencias[entry.key],
            desglose: 'oficial',
            onTap: tasaLibre == null
                ? null
                : () => context.go(
                    _detalleUri('moneda', entry.key, 'Tasa oficial'),
                  ),
          ),
        );
      }
    }

    return filas;
  }

  List<Widget> _seccionProductos() {
    final productos = _productos;
    if (productos == null || productos.categorias.isEmpty) {
      return const [
        _MensajeFinanzas(texto: 'Aun no hay productos con precios registrados.'),
      ];
    }

    final widgets = <Widget>[];
    for (final categoria in productos.categorias) {
      widgets.add(_CategoriaCard(categoria: categoria));
      widgets.add(const SizedBox(height: 10));
    }
    if (!productos.conversionCup) {
      widgets.add(
        const _MensajeFinanzas(
          texto: 'Sin tasa de referencia para convertir algunas monedas.',
        ),
      );
    }
    return widgets;
  }
}

class _EncabezadoFinanzas extends StatelessWidget {
  const _EncabezadoFinanzas({this.actualizadoEn});

  final String? actualizadoEn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finanzas',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          actualizadoEn == null || actualizadoEn!.isEmpty
              ? 'Cotizaciones de monedas y precios de productos.'
              : 'Cotizaciones y precios de productos. Actualizado ${_fechaCorta(actualizadoEn!)}.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  String _fechaCorta(String iso) {
    final fecha = DateTime.tryParse(iso);
    if (fecha == null) return iso;
    final hora = fecha.toLocal();
    final mm = hora.minute.toString().padLeft(2, '0');
    final hh = hora.hour.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _SeccionFinanzas extends StatelessWidget {
  const _SeccionFinanzas({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _CargandoFinanzas extends StatelessWidget {
  const _CargandoFinanzas();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _MensajeFinanzas extends StatelessWidget {
  const _MensajeFinanzas({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }
}

class _MonedaFila extends StatelessWidget {
  const _MonedaFila({
    required this.codigo,
    required this.nombre,
    required this.valor,
    required this.desglose,
    this.tendencia,
    this.onTap,
  });

  final String codigo;
  final String nombre;
  final double? valor;
  final double? tendencia;
  final String desglose;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final alza = tendencia == null || tendencia! >= 0;
    final color = tendencia == null ? null : (alza ? _subida : _bajada);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.gold.withValues(alpha: 0.16),
          child: Text(
            codigo,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              color: AppColors.goldDark,
            ),
          ),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('Precio $desglose'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${valor == null ? '-' : formatoDinero(valor)} CUP',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontSize: 15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (tendencia != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tendencia! >= 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: color,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        formatearTendencia(tendencia),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _CategoriaCard extends StatefulWidget {
  const _CategoriaCard({required this.categoria});

  final CategoriaFinanzas categoria;

  @override
  State<_CategoriaCard> createState() => _CategoriaCardState();
}

class _CategoriaCardState extends State<_CategoriaCard> {
  bool _expandida = false;

  @override
  Widget build(BuildContext context) {
    final categoria = widget.categoria;
    final alza = categoria.tendenciaPorcentual == null ||
        categoria.tendenciaPorcentual! >= 0;
    final colorVariacion =
        categoria.tendenciaPorcentual == null ? null : (alza ? _subida : _bajada);
    final variantes = _agruparVariantes(categoria.productos);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandida = !_expandida),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoria.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${categoria.totalProductos} productos '
                          'en ${categoria.negocios} negocios',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (categoria.promedioCup != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${formatoDinero(categoria.promedioCup)} CUP',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (categoria.tendenciaPorcentual != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoria.tendenciaPorcentual! >= 0
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 13,
                                color: colorVariacion,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                formatearTendencia(categoria.tendenciaPorcentual),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorVariacion,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    _expandida
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_expandida) ...[
            const Divider(height: 1),
            ..._variantesWidgets(variantes, categoria.productos.length),
          ],
        ],
      ),
    );
  }

  List<Widget> _variantesWidgets(List<_VarianteFinanzas> variantes, int total) {
    const maxVisibles = 8;
    final visibles = variantes.take(maxVisibles).toList();
    final widgets = <Widget>[
      for (final variante in visibles) _VarianteFila(variante: variante),
      if (variantes.length > maxVisibles)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Text(
            'Y ${variantes.length - maxVisibles} variantes mas de $total productos.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.goldDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];
    return widgets;
  }

  List<_VarianteFinanzas> _agruparVariantes(List<ProductoFinanzas> productos) {
    final grupos = <String, List<ProductoFinanzas>>{};
    for (final producto in productos) {
      grupos.putIfAbsent(producto.descripcion, () => []).add(producto);
    }
    final variantes = <_VarianteFinanzas>[];
    for (final entrada in grupos.entries) {
      final miembros = entrada.value;
      final precios = miembros
          .map((p) => p.precioCup)
          .whereType<double>()
          .toList();
      final tendencias = miembros
          .map((p) => p.tendenciaPorcentual)
          .whereType<double>()
          .toList();
      variantes.add(
        _VarianteFinanzas(
          etiqueta: entrada.key,
          productos: miembros.length,
          precioCup: precios.isEmpty
              ? null
              : precios.reduce((a, b) => a + b) / precios.length,
          tendencia: tendencias.isEmpty
              ? null
              : tendencias.reduce((a, b) => a + b) / tendencias.length,
          productoRepresentante: miembros.first,
        ),
      );
    }
    variantes.sort((a, b) {
      final pa = a.precioCup ?? double.maxFinite;
      final pb = b.precioCup ?? double.maxFinite;
      return pa.compareTo(pb);
    });
    return variantes;
  }
}

class _VarianteFinanzas {
  const _VarianteFinanzas({
    required this.etiqueta,
    required this.productos,
    required this.precioCup,
    required this.tendencia,
    required this.productoRepresentante,
  });

  final String etiqueta;
  final int productos;
  final double? precioCup;
  final double? tendencia;
  final ProductoFinanzas productoRepresentante;
}

class _VarianteFila extends StatelessWidget {
  const _VarianteFila({required this.variante});

  final _VarianteFinanzas variante;

  @override
  Widget build(BuildContext context) {
    final tendencia = variante.tendencia;
    final alza = tendencia == null || tendencia >= 0;
    final color = tendencia == null ? null : (alza ? _subida : _bajada);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: const Icon(Icons.local_offer_outlined, size: 18),
      title: Text(
        variante.etiqueta,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          variante.productos > 1
              ? 'Promedio de ${variante.productos} anuncios'
              : 'Precio de 1 anuncio',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                variante.precioCup == null
                    ? '-'
                    : '${formatoDinero(variante.precioCup)} CUP',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (tendencia != null)
                Text(
                  formatearTendencia(tendencia),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
      onTap: () => context.go(
        _detalleUri('producto', variante.productoRepresentante.id, variante.etiqueta),
      ),
    );
  }
}