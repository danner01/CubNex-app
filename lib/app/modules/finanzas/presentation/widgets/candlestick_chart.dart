import 'package:flutter/material.dart';

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

class CandlestickChart extends StatelessWidget {
  const CandlestickChart({super.key, required this.candelas});

  final List<Candle> candelas;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.fromHeight(230),
      painter: _CandlestickPainter(candelas: candelas),
    );
  }
}

const _violetaUp = Color(0xFF2ECC71);
const _rojoDown = Color(0xFFE74C3C);
const _ejeTonal = Color(0xFF8A8A8A);

class _CandlestickPainter extends CustomPainter {
  _CandlestickPainter({required this.candelas});

  final List<Candle> candelas;
  static const double _axisWidth = 52;
  static const double _padTop = 14;
  static const double _padBottom = 20;
  static const double _padLeft = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (candelas.isEmpty) return;
    final plotWidth = size.width - _axisWidth - _padLeft;
    final plotHeight = size.height - _padTop - _padBottom;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    var min = candelas.first.low;
    var max = candelas.first.high;
    for (final candela in candelas) {
      if (candela.low < min) min = candela.low;
      if (candela.high > max) max = candela.high;
    }
    final rango = (max - min) * 0.08;
    var base = min - rango;
    var tope = max + rango;
    if (tope <= base) {
      tope = base + 1;
    }

    _pintarGridYPrecios(canvas, size, base, tope, plotHeight);

    final n = candelas.length;
    final paso = plotWidth / n;
    final anchoCuerpo = (paso * 0.62).clamp(2.0, 14.0);

    for (var i = 0; i < n; i++) {
      final candela = candelas[i];
      final color = candela.alcista ? _violetaUp : _rojoDown;
      final xCentro = _padLeft + paso * (i + 0.5);

      final paintWick = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(xCentro, _valorAY(candela.high, base, tope, plotHeight)),
        Offset(xCentro, _valorAY(candela.low, base, tope, plotHeight)),
        paintWick,
      );

      final maximo = candela.open > candela.close ? candela.open : candela.close;
      final minimo = candela.open > candela.close ? candela.close : candela.open;
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
            ..strokeWidth = 1.4,
        );
      }
    }

    _pintarFechas(canvas, size, paso);
  }

  double _valorAY(
    double valor,
    double base,
    double tope,
    double plotHeight,
  ) {
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
    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
    );
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

  void _pintarFechas(
    Canvas canvas,
    Size size,
    double paso,
  ) {
    if (candelas.isEmpty) return;
    final textPaint = TextPainter(textDirection: TextDirection.ltr);
    void pintar(String texto, double x, {required bool alinearDerecha}) {
      textPaint.text = TextSpan(
        text: texto,
        style: const TextStyle(fontSize: 9, color: _ejeTonal),
      );
      textPaint.layout();
      final dx = alinearDerecha ? x - textPaint.width : x;
      textPaint.paint(
        canvas,
        Offset(dx.clamp(_padLeft, size.width - _axisWidth - textPaint.width), size.height - 16),
      );
    }

    pintar(_fechaCorta(candelas.first.tiempo), _padLeft, alinearDerecha: false);
    pintar(
      _fechaCorta(candelas.last.tiempo),
      _padLeft + paso * (candelas.length - 0.5),
      alinearDerecha: true,
    );
  }

  String _formatoEje(double valor) {
    if (valor.abs() >= 1000) {
      return valor.toStringAsFixed(0);
    }
    return valor.toStringAsFixed(1);
  }

  String _fechaCorta(DateTime tiempo) {
    final meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${tiempo.day}/${meses[tiempo.month - 1]}';
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.candelas != candelas;
  }
}