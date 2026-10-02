import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/injection/injection.dart';
import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../../services/finanzas/finanzas_formatos.dart';
import '../../services/finanzas/finanzas_models.dart';
import '../../services/finanzas/finanzas_service.dart';

const _ledVerde = Color(0xFF54E874);
const _ledRojo = Color(0xFFFF5454);
const _textoTicker = Color(0xFFF0E3BE);

class FinanceTickerBar extends StatefulWidget {
  const FinanceTickerBar({super.key});

  @override
  State<FinanceTickerBar> createState() => _FinanceTickerBarState();
}

class _FinanceTickerBarState extends State<FinanceTickerBar>
    with WidgetsBindingObserver {
  final FinanzasService _finanzasService = sl<FinanzasService>();
  TickerSnapshot? _snapshot;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargar(force: true);
    }
  }

  Future<void> _cargar({bool force = false}) async {
    final snapshot = await _finanzasService.obtenerTicker(force: force);
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  void _ocultar() {
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final items = <_TickItem>[];
    for (final moneda in _snapshot?.monedas ?? const <TickerMoneda>[]) {
      final valor = moneda.valor;
      if (valor == null) continue;
      items.add(
        _TickItem(
          codigo: monedaAbreviada(moneda.codigo),
          valor: valor,
          tendencia: moneda.tendencia,
        ),
      );
    }

    return SizedBox(
      height: 25,
      child: Material(
        color: AppColors.goldDark.withValues(alpha: 0.32),
        child: InkWell(
          onTap: () => context.go(AppRoutes.finanzas),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _TickerHairline(top: true),
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    'MERCADO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 52,
                right: 26,
                top: 0,
                bottom: 0,
                child: _TickerMarquee(
                  items: items,
                  cargando: _snapshot == null,
                ),
              ),
              const Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: _CloseTickerButton(),
              ),
              const _TickerHairline(top: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickerHairline extends StatelessWidget {
  const _TickerHairline({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
      child: Container(
        height: 1,
        color: AppColors.gold.withValues(alpha: 0.42),
      ),
    );
  }
}

class _CloseTickerButton extends StatefulWidget {
  const _CloseTickerButton();

  @override
  State<_CloseTickerButton> createState() => _CloseTickerButtonState();
}

class _CloseTickerButtonState extends State<_CloseTickerButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final parent = context.findAncestorStateOfType<_FinanceTickerBarState>();
        parent?._ocultar();
      },
      child: const Padding(
        padding: EdgeInsets.all(5),
        child: Icon(
          Icons.close_rounded,
          size: 15,
          color: Color(0xFFB09A55),
        ),
      ),
    );
  }
}

class _TickItem {
  const _TickItem({required this.codigo, required this.valor, this.tendencia});

  final String codigo;
  final double valor;
  final double? tendencia;
}

class _TickerMarquee extends StatefulWidget {
  const _TickerMarquee({required this.items, required this.cargando});

  final List<_TickItem> items;
  final bool cargando;

  @override
  State<_TickerMarquee> createState() => _TickerMarqueeState();
}

class _TickerMarqueeState extends State<_TickerMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final GlobalKey _rowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowWidth = _rowKey.currentContext?.size?.width ?? 0;
    final medio = rowWidth / 2;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: 0,
        maxWidth: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final dx = medio <= 0 ? 0.0 : _controller.value * medio;
            return Transform.translate(
              offset: Offset(-dx, 0),
              child: Row(
                key: _rowKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._contenido,
                  const SizedBox(width: 40),
                  ..._contenido,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> get _contenido {
    if (widget.cargando) {
      return [
        const SizedBox(
          height: 25,
          child: Center(
            child: Text(
              'Cargando cotizaciones...',
              style: TextStyle(
                fontSize: 9,
                color: Color(0xFFB0A26E),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      for (final item in widget.items) _TickerCell(item: item),
    ];
  }
}

class _TickerCell extends StatelessWidget {
  const _TickerCell({required this.item});

  final _TickItem item;

  @override
  Widget build(BuildContext context) {
    final tendencia = item.tendencia;
    final alza = tendencia == null || tendencia >= 0;
    final led = alza ? _ledVerde : _ledRojo;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.codigo,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: _textoTicker,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatoDinero(item.valor),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: led,
              letterSpacing: 0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                Shadow(color: led.withValues(alpha: 0.55), blurRadius: 5),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            tendencia == null
                ? Icons.remove_rounded
                : (tendencia >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
            size: 12,
            color: led,
          ),
          const SizedBox(width: 2),
          Text(
            formatearTendencia(tendencia),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: led,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}