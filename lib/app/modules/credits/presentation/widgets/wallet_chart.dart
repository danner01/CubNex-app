import 'package:flutter/material.dart';

import '../../data/models/credit_movement.dart';

enum WalletChartPeriod { day, week, month, year, all }

const walletPeriodLabel = <WalletChartPeriod, String>{
  WalletChartPeriod.day: 'Día',
  WalletChartPeriod.week: 'Semana',
  WalletChartPeriod.month: 'Mes',
  WalletChartPeriod.year: 'Año',
  WalletChartPeriod.all: 'Todo',
};

enum WalletCategory { ganados, recargados, depositados, transferidos, retirados, gastados }

const walletCategoryLabel = <WalletCategory, String>{
  WalletCategory.ganados: 'Ganados',
  WalletCategory.recargados: 'Recargados',
  WalletCategory.depositados: 'Depositados',
  WalletCategory.transferidos: 'Transferidos',
  WalletCategory.retirados: 'Retirados',
  WalletCategory.gastados: 'Gastados',
};

Color walletCategoryColor(WalletCategory c, ColorScheme theme) {
  return switch (c) {
    WalletCategory.ganados => theme.primary,
    WalletCategory.recargados => Colors.green,
    WalletCategory.depositados => Colors.teal,
    WalletCategory.transferidos => Colors.orange,
    WalletCategory.retirados => Colors.redAccent,
    WalletCategory.gastados => Colors.blueGrey,
  };
}

/// Clasifica un movimiento usando granos_delta como metrica principal
/// (fallback creditos_delta), espejo de buildWalletBreakdown del backend.
WalletCategory classifyMovement(CreditMovement m) {
  final tipo = m.type;
  final valor = m.granosDelta != 0 ? m.granosDelta : m.creditosDelta;
  final accion = m.accionType ?? '';

  switch (tipo) {
    case 'recarga':
      return WalletCategory.recargados;
    case 'transferencia_salida':
      return WalletCategory.transferidos;
    case 'transferencia_entrada':
      return WalletCategory.depositados;
    case 'gana':
      return WalletCategory.ganados;
    case 'consume':
    case 'impuesto':
    case 'comision':
      return WalletCategory.gastados;
    case 'ajuste':
      if (valor < 0 && accion == 'conversion_granos') {
        return WalletCategory.retirados;
      }
      if (valor < 0) return WalletCategory.gastados;
      return WalletCategory.ganados;
    default:
      return valor < 0 ? WalletCategory.gastados : WalletCategory.ganados;
  }
}

class WalletChart extends StatefulWidget {
  const WalletChart({super.key, required this.movements});

  final List<CreditMovement> movements;

  @override
  State<WalletChart> createState() => _WalletChartState();
}

class _WalletChartState extends State<WalletChart> {
  WalletChartPeriod _period = WalletChartPeriod.month;
  final Set<WalletCategory> _selected = {
    WalletCategory.ganados,
    WalletCategory.recargados,
    WalletCategory.depositados,
  };

  DateTime _periodStart(WalletChartPeriod period, DateTime now) {
    switch (period) {
      case WalletChartPeriod.day:
        return DateTime(now.year, now.month, now.day);
      case WalletChartPeriod.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case WalletChartPeriod.month:
        return DateTime(now.year, now.month, 1);
      case WalletChartPeriod.year:
        return DateTime(now.year, 1, 1);
      case WalletChartPeriod.all:
        return DateTime(2000);
    }
  }

  int _bucketIndex(DateTime date, WalletChartPeriod period, DateTime now) {
    switch (period) {
      case WalletChartPeriod.day:
        return date.hour;
      case WalletChartPeriod.week:
        final start = _periodStart(WalletChartPeriod.week, now);
        return DateTime(date.year, date.month, date.day)
            .difference(DateTime(start.year, start.month, start.day))
            .inDays;
      case WalletChartPeriod.month:
        return date.day - 1;
      case WalletChartPeriod.year:
        return date.month - 1;
      case WalletChartPeriod.all:
        return now.year - date.year;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final periodStart = _periodStart(_period, now);
    final filtered = widget.movements
        .where((m) =>
            m.createdAt != null &&
            m.createdAt!.isAfter(periodStart) &&
            _selected.contains(classifyMovement(m)))
        .toList();

    final bucketCount = switch (_period) {
      WalletChartPeriod.day => 24,
      WalletChartPeriod.week => 7,
      WalletChartPeriod.month => 31,
      WalletChartPeriod.year => 12,
      WalletChartPeriod.all => (now.year - 2000 + 1).clamp(1, 40),
    };
    final bucketSlices = List.generate(
      bucketCount,
      (_) => <({WalletCategory cat, double value})>[],
    );
    for (final m in filtered) {
      final idx = _bucketIndex(m.createdAt!, _period, now);
      if (idx < 0 || idx >= bucketCount) continue;
      final cat = classifyMovement(m);
      final v = m.granosDelta != 0 ? m.granosDelta : m.creditosDelta;
      final list = bucketSlices[idx];
      final existing = list.indexWhere((s) => s.cat == cat);
      if (existing >= 0) {
        list[existing] = (
          cat: cat,
          value: list[existing].value + v.abs().toDouble(),
        );
      } else {
        list.add((cat: cat, value: v.abs().toDouble()));
      }
    }

    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Período',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(width: 8),
            DropdownButton<WalletChartPeriod>(
              value: _period,
              isDense: true,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              style: Theme.of(context).textTheme.labelLarge,
              items: WalletChartPeriod.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(walletPeriodLabel[p]!),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _period = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: WalletCategory.values.map((c) {
            final selected = _selected.contains(c);
            return FilterChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              side: BorderSide(
                color: selected ? walletCategoryColor(c, colors) : colors.outlineVariant,
                width: selected ? 1.4 : 1,
              ),
              showCheckmark: false,
              checkmarkColor: colors.onSurface,
              selectedColor: walletCategoryColor(c, colors).withValues(alpha: 0.16),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text(
                walletCategoryLabel[c]!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _selected.add(c);
                } else {
                  _selected.remove(c);
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(
            painter: _WalletChartPainter(
              bucketSlices: bucketSlices,
              maxBucket: bucketCount,
              period: _period,
              theme: colors,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Granos por período, según la selección. Cada color es una categoría.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _WalletChartPainter extends CustomPainter {
  _WalletChartPainter({
    required this.bucketSlices,
    required this.maxBucket,
    required this.period,
    required this.theme,
  });

  final List<List<({WalletCategory cat, double value})>> bucketSlices;
  final int maxBucket;
  final WalletChartPeriod period;
  final ColorScheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 36.0;
    final rightPad = 10.0;
    final topPad = 12.0;
    final bottomPad = 24.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final bucketTotals = bucketSlices.map(
      (slices) => slices.fold<double>(0, (acc, s) => acc + s.value),
    ).toList();
    final maxValue = bucketTotals.fold<double>(1, (acc, b) => b > acc ? b : acc);
    final labelStyle = TextStyle(color: theme.onSurfaceVariant, fontSize: 10);
    final tp = TextPainter(
      text: TextSpan(text: maxValue.toStringAsFixed(0), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(leftPad - tp.width - 4, topPad - 4));

    final guidePaint = Paint()
      ..color = theme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topPad + chartHeight - (chartHeight * (i / 3));
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + chartWidth, y), guidePaint);
    }

    final hasData = bucketSlices.any((s) => s.isNotEmpty);
    if (!hasData) {
      final empty = TextPainter(
        text: TextSpan(
          text: 'Sin movimientos en el período',
          style: TextStyle(color: theme.onSurfaceVariant, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      empty.paint(
        canvas,
        Offset(leftPad + (chartWidth - empty.width) / 2, topPad + chartHeight / 2 - 8),
      );
      return;
    }

    final n = bucketSlices.length;
    final barWidth = (chartWidth / maxBucket).clamp(2.0, chartWidth / 2);

    for (int i = 0; i < n; i++) {
      final slices = bucketSlices[i];
      if (slices.isEmpty) continue;
      final x = leftPad + (chartWidth * i / n);
      var cursorY = topPad + chartHeight;
      for (final s in slices) {
        final value = s.value;
        if (value <= 0) continue;
        final barH = (value / maxValue) * chartHeight;
        final rect = Rect.fromLTRB(
          x,
          cursorY - barH,
          x + barWidth,
          cursorY,
        );
        final paint = Paint()
          ..color = walletCategoryColor(s.cat, theme);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
            bottomLeft: const Radius.circular(2),
            bottomRight: const Radius.circular(2),
          ),
          paint,
        );
        cursorY -= barH;
      }
    }

    // etiquetas de eje X
    final step = (n / 6).ceil();
    for (int i = 0; i < n; i += step) {
      final x = leftPad + (chartWidth * i / n);
      final tpLabel = TextPainter(
        text: TextSpan(text: _axisLabel(i, n), style: TextStyle(fontSize: 9, color: theme.onSurfaceVariant)),
        textDirection: TextDirection.ltr,
      )..layout();
      tpLabel.paint(canvas, Offset((x - tpLabel.width / 2).clamp(leftPad, leftPad + chartWidth - tpLabel.width), topPad + chartHeight + 4));
    }
  }

  String _axisLabel(int i, int n) {
    switch (period) {
      case WalletChartPeriod.day:
        return '${i}h';
      case WalletChartPeriod.week:
        return 'D${i + 1}';
      case WalletChartPeriod.month:
        return '${i + 1}';
      case WalletChartPeriod.year:
        const names = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
        return names[i];
      case WalletChartPeriod.all:
        return '${2000 + i}';
    }
  }

  @override
  bool shouldRepaint(covariant _WalletChartPainter oldDelegate) {
    return oldDelegate.bucketSlices != bucketSlices ||
        oldDelegate.period != period ||
        oldDelegate.theme != theme;
  }
}
