import 'package:flutter/material.dart';

import '../../services/tasas/tasas_models.dart';
import '../../services/tasas/tasas_service.dart';
import '../../../config/injection/injection.dart';

class CambioHoyCard extends StatefulWidget {
  const CambioHoyCard({super.key, this.compact = false});

  final bool compact;

  @override
  State<CambioHoyCard> createState() => _CambioHoyCardState();
}

class _CambioHoyCardState extends State<CambioHoyCard> {
  late Future<TasasMercado?> _referenciaFuture;
  bool _loadingHistorial = false;
  List<TasaHistorialPunto> _historial = const [];

  @override
  void initState() {
    super.initState();
    _referenciaFuture = sl<TasasService>().obtenerReferencia();
  }

  Future<void> _loadHistorial() async {
    if (_historial.isNotEmpty || _loadingHistorial) return;
    setState(() => _loadingHistorial = true);
    final puntos = await sl<TasasService>().obtenerHistorial(
      moneda: 'USD',
      fuente: 'eltoque',
      dias: 7,
    );
    if (!mounted) return;
    setState(() {
      _historial = puntos;
      _loadingHistorial = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TasasMercado?>(
      future: _referenciaFuture,
      builder: (context, snapshot) {
        final mercado = snapshot.data;
        final loading =
            snapshot.connectionState == ConnectionState.waiting;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.currency_exchange,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cambio y precios',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (!loading && mercado != null)
                      Text(
                        _fuenteLabel(mercado.fuente),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Referencia del mercado para comparar precios en CUP.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (mercado == null || mercado.tasas.isEmpty)
                  _ErrorRetry(onRetry: () {
                    setState(() {
                      _referenciaFuture = sl<TasasService>()
                          .obtenerReferencia();
                    });
                  })
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const ['USD', 'EUR', 'MLC', 'USDT']
                        .map((codigo) {
                          final tasa = mercado.tasas[codigo];
                          return _RateTile(
                            codigo: codigo,
                            nombre: tasa?.nombre ?? codigo,
                            cup: tasa?.cup,
                            compra: tasa?.compra,
                            venta: tasa?.venta,
                          );
                        })
                        .toList(),
                  ),
                  if (mercado.oficial.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _OficialRow(
                      cadeca: mercado.oficial['USD'],
                      bcc: mercado.oficial['BCC'] ?? mercado.oficial['usd'],
                    ),
                  ],
                  const SizedBox(height: 10),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _historial.isNotEmpty
                        ? _HistorialList(puntos: _historial)
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _loadingHistorial
                                  ? null
                                  : _loadHistorial,
                              icon: _loadingHistorial
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.show_chart_outlined,
                                      size: 18,
                                    ),
                              label: const Text(
                                'Ver historial del dolar',
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _fuenteLabel(String fuente) {
    return switch (fuente) {
      'tasalo' => 'Fuente: TASALO',
      'eltoque' => 'Fuente: ElToque',
      'ninguna' => '',
      _ => fuente.isEmpty ? '' : 'Fuente: $fuente',
    };
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.codigo,
    required this.nombre,
    this.cup,
    this.compra,
    this.venta,
  });

  final String codigo;
  final String nombre;
  final double? cup;
  final double? compra;
  final double? venta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 142,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  codigo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nombre,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cup == null ? 'Sin dato' : '${_fmt(cup!)} CUP',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: cup == null ? scheme.outline : null,
            ),
          ),
          if (compra != null && venta != null) ...[
            const SizedBox(height: 2),
            Text(
              'Compra ${_fmt(compra!)} / Venta ${_fmt(venta!)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _OficialRow extends StatelessWidget {
  const _OficialRow({this.cadeca, this.bcc});

  final TasaValor? cadeca;
  final TasaValor? bcc;

  @override
  Widget build(BuildContext context) {
    final valores = <(String, TasaValor?)>[
      ('CADECA', cadeca),
      ('BCC', bcc),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: valores.map((entry) {
        final (label, valor) = entry;
        if (valor == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.6),
          ),
          child: Text(
            '$label oficial: Compra ${valor.compra == null ? '-' : _fmt(valor.compra!)} '
            '/ Venta ${valor.venta == null ? '-' : _fmt(valor.venta!)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        );
      }).toList(),
    );
  }
}

class _HistorialList extends StatelessWidget {
  const _HistorialList({required this.puntos});

  final List<TasaHistorialPunto> puntos;

  @override
  Widget build(BuildContext context) {
    final ultimos = puntos.length > 24
        ? puntos.sublist(puntos.length - 24)
        : puntos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historial del dolar (7 dias)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: ultimos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final punto = ultimos[index];
              final prev = index > 0 ? ultimos[index - 1].cup : null;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _formatFecha(punto.fecha),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (punto.cup != null && prev != null) ...[
                      Icon(
                        punto.cup! >= prev
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: punto.cup! >= prev
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      punto.cup == null ? '-' : '${_fmt(punto.cup!)} CUP',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatFecha(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final now = DateTime.now();
    String dia;
    if (parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day) {
      dia = 'Hoy';
    } else if (parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day - 1) {
      dia = 'Ayer';
    } else {
      dia = '${parsed.day.toString().padLeft(2, '0')}/'
          '${parsed.month.toString().padLeft(2, '0')}';
    }
    final hora = '${parsed.hour.toString().padLeft(2, '0')}'
        ':${parsed.minute.toString().padLeft(2, '0')}';
    return '$dia $hora';
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('No pudimos obtener las tasas ahora mismo.'),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}

String _fmt(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  if (rounded == rounded.roundToDouble()) {
    return '${rounded.toInt()}';
  }
  return '$rounded'.replaceAll('.', ',');
}