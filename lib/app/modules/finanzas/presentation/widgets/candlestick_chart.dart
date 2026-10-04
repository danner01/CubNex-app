import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../common/services/finanzas/finanzas_formatos.dart';

class Candle {
  const Candle({
    required this.tiempo,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final DateTime tiempo;
  final double open;
  final double high;
  final double low;
  final double close;

  bool get alcista => close >= open;

  Candle copyWithTiempo(DateTime nuevo) {
    return Candle(
      tiempo: nuevo,
      open: open,
      high: high,
      low: low,
      close: close,
    );
  }
}

class CandlestickChart extends StatefulWidget {
  const CandlestickChart({
    super.key,
    required this.candelas,
    this.altura = 240,
    this.mediaPeriodos = 7,
    this.proyeccionPeriodos = 5,
  });

  final List<Candle> candelas;
  final double altura;
  final int mediaPeriodos;
  final int proyeccionPeriodos;

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  int? _indiceSeleccionado;

  @override
  Widget build(BuildContext context) {
    final candelas = widget.candelas;
    if (candelas.isEmpty) return const SizedBox(height: 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LeyendaInteractiva(
          mediaPeriodos: widget.mediaPeriodos,
          proyeccionPeriodos: widget.proyeccionPeriodos,
          proyecto: _proyeccion(),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: widget.altura,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _sobreIndice(constraints.maxWidth),
                onHorizontalDragStart: (detail) =>
                    _seleccionar(detail.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (detail) =>
                    _seleccionar(detail.localPosition.dx, constraints.maxWidth),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.altura),
                  painter: _CandlestickPainter(
                    candelas: candelas,
                    mediaPeriodos: widget.mediaPeriodos,
                    proyeccionPeriodos: widget.proyeccionPeriodos,
                    indiceSeleccionado: _indiceSeleccionado,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (_indiceSeleccionado != null) ...[
          _DetalleVela(candela: candelas[_indiceSeleccionado!]),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  GestureTapDownCallback _sobreIndice(double width) {
    return (detail) => _seleccionar(detail.localPosition.dx, width);
  }

  void _seleccionar(double dx, double width) {
    final candelas = widget.candelas;
    if (candelas.isEmpty) return;
    final slots = candelas.length + widget.proyeccionPeriodos;
    final paso = (width - _padLeft - _axisWidth) / slots;
    if (paso <= 0) return;
    final indice = ((dx - _padLeft) / paso - 0.5).floor().clamp(
      0,
      candelas.length - 1,
    );
    setState(() => _indiceSeleccionado = indice);
  }

  RegresionLineal? _regresion() {
    return _regresionLineal(widget.candelas);
  }

  double? _proyeccion() {
    final reg = _regresion();
    if (reg == null) return null;
    final ultimo = widget.candelas.last.tiempo.millisecondsSinceEpoch;
    final xFinal = ultimo + widget.proyeccionPeriodos * _pasoTemporal();
    return reg.slope * xFinal + reg.intercept;
  }

  double _pasoTemporal() {
    final candelas = widget.candelas;
    if (candelas.length < 2) return 1;
    final rango =
        candelas.last.tiempo.millisecondsSinceEpoch -
        candelas.first.tiempo.millisecondsSinceEpoch;
    return rango / math.max(1, candelas.length - 1);
  }
}

class RegresionLineal {
  const RegresionLineal({required this.slope, required this.intercept});

  final double slope;
  final double intercept;
}

RegresionLineal? _regresionLineal(List<Candle> candelas) {
  if (candelas.length < 2) return null;
  final lista = candelas.length > 14
      ? candelas.sublist(candelas.length - 14)
      : candelas;
  final n = lista.length;
  double sx = 0, sy = 0, sxy = 0, sxx = 0;
  for (var i = 0; i < n; i++) {
    final x = lista[i].tiempo.millisecondsSinceEpoch.toDouble();
    final y = lista[i].close;
    sx += x;
    sy += y;
    sxy += x * y;
    sxx += x * x;
  }
  final denominador = n * sxx - sx * sx;
  if (denominador == 0) return null;
  final slope = (n * sxy - sx * sy) / denominador;
  final intercept = (sy - slope * sx) / n;
  return RegresionLineal(slope: slope, intercept: intercept);
}

const _violetaUp = Color(0xFF2ECC71);
const _rojoDown = Color(0xFFE74C3C);
const _ejeTonal = Color(0xFF8A8A8A);
const _smaColor = Color(0xFFD4AF37);
const _proyeccionColor = Color(0xFF5F8DEB);

const _padTop = 14.0;
const _padBottom = 20.0;
const _padLeft = 6.0;
const _axisWidth = 52.0;

class _CandlestickPainter extends CustomPainter {
  _CandlestickPainter({
    required this.candelas,
    required this.mediaPeriodos,
    required this.proyeccionPeriodos,
    required this.indiceSeleccionado,
  });

  final List<Candle> candelas;
  final int mediaPeriodos;
  final int proyeccionPeriodos;
  final int? indiceSeleccionado;

  @override
  void paint(Canvas canvas, Size size) {
    if (candelas.isEmpty) return;

    final reg = _regresionLineal(candelas);
    final slots = candelas.length + proyeccionPeriodos;
    final plotWidth = size.width - _axisWidth - _padLeft;
    final plotHeight = size.height - _padTop - _padBottom;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    var min = candelas.first.low;
    var max = candelas.first.high;
    for (final candela in candelas) {
      if (candela.low < min) min = candela.low;
      if (candela.high > max) max = candela.high;
    }

    final sma = _smaDeCierres(candelas, mediaPeriodos);
    for (final valor in sma) {
      if (valor != null) {
        if (valor < min) min = valor;
        if (valor > max) max = valor;
      }
    }

    final xMax =
        candelas.last.tiempo.millisecondsSinceEpoch.toDouble() +
        _pasoTemporal(candelas) * proyeccionPeriodos;

    if (reg != null) {
      final x0 = candelas.last.tiempo.millisecondsSinceEpoch.toDouble();
      final y0 = reg.slope * x0 + reg.intercept;
      final y1 = reg.slope * xMax + reg.intercept;
      if (y0 < min) min = y0;
      if (y0 > max) max = y0;
      if (y1 < min) min = y1;
      if (y1 > max) max = y1;
    }

    final rango = (max - min) * 0.08;
    var base = min - rango;
    var tope = max + rango;
    if (tope <= base) tope = base + 1;

    _pintarGridYPrecios(canvas, size, base, tope, plotHeight);

    final paso = plotWidth / slots;
    final anchoCuerpo = (paso * 0.62).clamp(2.0, 14.0);

    double xDe(int indice) => _padLeft + paso * (indice + 0.5);

    for (var i = 0; i < candelas.length; i++) {
      final candela = candelas[i];
      final seleccionada = i == indiceSeleccionado;
      final color = candela.alcista ? _violetaUp : _rojoDown;
      final xCentro = xDe(i);

      final paintWick = Paint()
        ..color = color.withValues(alpha: seleccionada ? 1 : 0.85)
        ..strokeWidth = seleccionada ? 1.6 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(xCentro, _valorAY(candela.high, base, tope, plotHeight)),
        Offset(xCentro, _valorAY(candela.low, base, tope, plotHeight)),
        paintWick,
      );

      final maximo = candela.open > candela.close
          ? candela.open
          : candela.close;
      final minimo = candela.open > candela.close
          ? candela.close
          : candela.open;
      final rect = Rect.fromLTRB(
        xCentro - anchoCuerpo / 2,
        _valorAY(maximo, base, tope, plotHeight),
        xCentro + anchoCuerpo / 2,
        _valorAY(minimo, base, tope, plotHeight),
      );
      if (candela.alcista) {
        canvas.drawRect(rect, Paint()..color = color);
      } else {
        canvas.drawRect(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = seleccionada ? 2 : 1.4,
        );
      }
      if (seleccionada) {
        canvas.drawRect(
          rect.inflate(2.5),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        canvas.drawCircle(
          Offset(xCentro, _valorAY(candela.close, base, tope, plotHeight)),
          3,
          Paint()..color = Colors.white,
        );
      }
    }

    _pintarSMA(canvas, size, sma, base, tope, plotHeight, paso);
    _pintarProyeccion(
      canvas,
      size,
      reg,
      base,
      tope,
      plotHeight,
      paso,
      candelas,
    );

    _pintarFechas(canvas, size, paso, slots);
  }

  List<double?> _smaDeCierres(List<Candle> candelas, int periodos) {
    final salida = List<double?>.filled(candelas.length, null);
    if (periodos <= 1) {
      for (var i = 0; i < candelas.length; i++) {
        salida[i] = candelas[i].close;
      }
      return salida;
    }
    double suma = 0;
    for (var i = 0; i < candelas.length; i++) {
      suma += candelas[i].close;
      if (i >= periodos) suma -= candelas[i - periodos].close;
      if (i >= periodos - 1) salida[i] = suma / periodos;
    }
    return salida;
  }

  void _pintarSMA(
    Canvas canvas,
    Size size,
    List<double?> sma,
    double base,
    double tope,
    double plotHeight,
    double paso,
  ) {
    final path = Path();
    var iniciado = false;
    for (var i = 0; i < sma.length; i++) {
      final valor = sma[i];
      if (valor == null) {
        iniciado = false;
        continue;
      }
      final punto = Offset(
        _padLeft + paso * (i + 0.5),
        _valorAY(valor, base, tope, plotHeight),
      );
      if (!iniciado) {
        path.moveTo(punto.dx, punto.dy);
        iniciado = true;
      } else {
        path.lineTo(punto.dx, punto.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _smaColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _pintarProyeccion(
    Canvas canvas,
    Size size,
    RegresionLineal? reg,
    double base,
    double tope,
    double plotHeight,
    double paso,
    List<Candle> candelas,
  ) {
    if (reg == null) return;
    final ultima = candelas.last;
    final xUltima = _padLeft + paso * (candelas.length - 0.5);
    final yUltima = _valorAY(ultima.close, base, tope, plotHeight);
    final xProy =
        _padLeft + paso * (candelas.length - 0.5 + proyeccionPeriodos);
    final yProy = _valorAY(
      reg.slope * ultima.tiempo.millisecondsSinceEpoch.toDouble() +
          reg.slope * _pasoTemporal(candelas) * proyeccionPeriodos +
          reg.intercept,
      base,
      tope,
      plotHeight,
    );

    final paintLinea = Paint()
      ..color = _proyeccionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(xUltima, yUltima), Offset(xProy, yProy), paintLinea);

    final paintGuion = Paint()
      ..color = _proyeccionColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    const longitudGuion = 4.0;
    const espacioGuion = 3.0;
    var t = 0.0;
    final distancia = math.max(1.0, (xProy - xUltima).abs());
    while (t < distancia) {
      final xIni = xUltima + (xProy - xUltima) * (t / distancia);
      final xFin =
          xUltima + (xProy - xUltima) * ((t + longitudGuion) / distancia);
      canvas.drawLine(
        Offset(xIni, yUltima + (yProy - yUltima) * (t / distancia)),
        Offset(
          xFin,
          yUltima + (yProy - yUltima) * ((t + longitudGuion) / distancia),
        ),
        paintGuion,
      );
      t += longitudGuion + espacioGuion;
    }

    canvas.drawCircle(
      Offset(xProy, yProy),
      3,
      Paint()
        ..color = _proyeccionColor
        ..style = PaintingStyle.fill,
    );
  }

  double _pasoTemporal(List<Candle> candelas) {
    if (candelas.length < 2) return 1;
    final rango =
        candelas.last.tiempo.millisecondsSinceEpoch -
        candelas.first.tiempo.millisecondsSinceEpoch;
    return rango / math.max(1, candelas.length - 1);
  }

  double _valorAY(double valor, double base, double tope, double plotHeight) {
    return _padTop + plotHeight - ((valor - base) / (tope - base)) * plotHeight;
  }

  void _pintarGridYPrecios(
    Canvas canvas,
    Size size,
    double base,
    double tope,
    double plotHeight,
  ) {
    const lineas = 4;
    final gridPaint = Paint()
      ..color = const Color(0x1F000000)
      ..strokeWidth = 0.7;
    final textPaint = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= lineas; i++) {
      final fraccion = i / lineas;
      final valor = base + (tope - base) * (1 - fraccion);
      final yLinea = _valorAY(valor, base, tope, plotHeight);
      canvas.drawLine(
        Offset(_padLeft, yLinea),
        Offset(size.width - _axisWidth, yLinea),
        gridPaint,
      );
      textPaint.text = TextSpan(
        text: _formatoEje(valor),
        style: const TextStyle(
          fontSize: 9,
          color: _ejeTonal,
          fontWeight: FontWeight.w500,
        ),
      );
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(size.width - _axisWidth + 4, yLinea - textPaint.height / 2),
      );
    }
  }

  void _pintarFechas(Canvas canvas, Size size, double paso, int slots) {
    if (candelas.isEmpty) return;
    final textPaint = TextPainter(textDirection: TextDirection.ltr);
    void pintar(String texto, double x, {required bool alinearDerecha}) {
      textPaint.text = TextSpan(
        text: texto,
        style: const TextStyle(fontSize: 9, color: _ejeTonal),
      );
      textPaint.layout();
      final baseDx = alinearDerecha ? x - textPaint.width : x;
      final dx = baseDx
          .clamp(_padLeft, size.width - _axisWidth - textPaint.width)
          .toDouble();
      textPaint.paint(canvas, Offset(dx, size.height - 16));
    }

    pintar(_fechaCorta(candelas.first.tiempo), _padLeft, alinearDerecha: false);
    pintar(
      _fechaCorta(candelas.last.tiempo),
      _padLeft + paso * (candelas.length - 0.5),
      alinearDerecha: true,
    );
    if (proyeccionPeriodos > 0) {
      final xProy =
          _padLeft + paso * (candelas.length - 0.5 + proyeccionPeriodos);
      textPaint.text = const TextSpan(
        text: 'proy',
        style: TextStyle(
          fontSize: 9,
          color: _proyeccionColor,
          fontWeight: FontWeight.w700,
        ),
      );
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(
          (xProy - textPaint.width / 2).clamp(
            0,
            size.width - _axisWidth - textPaint.width,
          ),
          _padTop + 2,
        ),
      );
    }
  }

  String _formatoEje(double valor) {
    if (valor.abs() >= 1000) {
      return valor.toStringAsFixed(0);
    }
    return valor.toStringAsFixed(1);
  }

  String _fechaCorta(DateTime tiempo) {
    final meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${tiempo.day}/${meses[tiempo.month - 1]}';
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.candelas != candelas ||
        oldDelegate.mediaPeriodos != mediaPeriodos ||
        oldDelegate.proyeccionPeriodos != proyeccionPeriodos ||
        oldDelegate.indiceSeleccionado != indiceSeleccionado;
  }
}

class _LeyendaInteractiva extends StatelessWidget {
  const _LeyendaInteractiva({
    required this.mediaPeriodos,
    required this.proyeccionPeriodos,
    required this.proyecto,
  });

  final int mediaPeriodos;
  final int proyeccionPeriodos;
  final double? proyecto;

  @override
  Widget build(BuildContext context) {
    final estiloMedio = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: _smaColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text('Media $mediaPeriodos', style: estiloMedio),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: _proyeccionColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text('Proyeccion ${proyeccionPeriodos}d', style: estiloMedio),
          ],
        ),
        if (proyecto != null)
          Text(
            'Prediccion: ${formatoDinero(proyecto)} CUP',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _proyeccionColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        const SizedBox(width: 4),
        Text(
          'Toca y arrastra para inspeccionar',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _DetalleVela extends StatelessWidget {
  const _DetalleVela({required this.candela});

  final Candle candela;

  @override
  Widget build(BuildContext context) {
    final alza = candela.alcista;
    final variacion = candela.open == 0
        ? 0.0
        : ((candela.close - candela.open) / candela.open) * 100;
    final color = alza ? _violetaUp : _rojoDown;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _fechaCompleta(candela.tiempo),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Icon(
                  alza
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 3),
                Text(
                  formatearTendencia(variacion),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _CeldaVelaDetalle('Apertura', candela.open),
                _CeldaVelaDetalle('Cierre', candela.close),
                _CeldaVelaDetalle('Maximo', candela.high),
                _CeldaVelaDetalle('Minimo', candela.low),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fechaCompleta(DateTime fecha) {
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} ${fecha.year}';
  }
}

class _CeldaVelaDetalle extends StatelessWidget {
  const _CeldaVelaDetalle(this.etiqueta, this.valor);

  final String etiqueta;
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatoDinero(valor),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
