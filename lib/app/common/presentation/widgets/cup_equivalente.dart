import 'package:flutter/material.dart';

import '../../services/tasas/tasas_service.dart';
import '../../../config/injection/injection.dart';

class CupEquivalente extends StatelessWidget {
  const CupEquivalente({
    super.key,
    required this.precio,
    this.moneda,
    this.style,
    this.prefix = 'Aprox.',
  });

  final double? precio;
  final String? moneda;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final monedaActual = moneda;
    if (precio == null || monedaActual == null || monedaActual == 'CUP') {
      return const SizedBox.shrink();
    }

    return FutureBuilder(
      future: sl<TasasService>().referenciaCached(),
      builder: (context, snapshot) {
        final mercado = snapshot.data;
        if (mercado == null) return const SizedBox.shrink();
        final tasa = mercado.tasas[monedaActual.toUpperCase()] ??
            (monedaActual == 'USD' ? mercado.tasas['USDT'] : null);
        final cup = tasa?.cup;
        if (cup == null || cup <= 0) return const SizedBox.shrink();

        final equivalente = precio! * cup;
        return Text(
          '$prefix ${_fmt(equivalente)} CUP',
          style: style ??
              Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        );
      },
    );
  }
}

String _fmt(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  if (rounded >= 10000) {
    return rounded.toStringAsFixed(0);
  }
  if (rounded == rounded.roundToDouble()) {
    return '${rounded.toInt()}';
  }
  return '$rounded'.replaceAll('.', ',');
}