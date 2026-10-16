import 'package:flutter/material.dart';

/// Codigos con asset propio en `assets/currencies/<code>.png`.
const Set<String> _monedasConAsset = {
  'USD',
  'EUR',
  'GBP',
  'CUP',
  'MLC',
  'USDT',
  'BCC',
  'BRL',
  'CAD',
  'CHF',
  'JPY',
  'MXN',
  'RUB',
  'AUD',
  'BTC',
  'ETH',
};

const String semillaAsset = 'assets/coins/semilla_1.png';
const String semillaCara2Asset = 'assets/coins/semilla_2.png';
const String _monedaGenericaAsset = 'assets/currencies/generic.png';

String assetMoneda(String? codigo) {
  final code = (codigo ?? '').trim().toUpperCase();
  if (code == 'SEM' || code == 'SEMILLA') return semillaAsset;
  if (_monedasConAsset.contains(code)) return 'assets/currencies/${code.toLowerCase()}.png';
  return _monedaGenericaAsset;
}

/// Icono circular de una moneda/cripto. Cae a un badge con el codigo si no hay
/// asset para el codigo recibido.
class MonedaIcon extends StatelessWidget {
  const MonedaIcon({super.key, required this.codigo, this.size = 40});

  final String? codigo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = (codigo ?? '').trim().toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          assetMoneda(code),
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, _, __) => _FallbackBadge(codigo: code, size: size),
        ),
      ),
    );
  }
}

/// Icono de la moneda Semilla (ConKkao), para usar inline donde se mencione.
class SemillaIcon extends StatelessWidget {
  const SemillaIcon({super.key, this.size = 18, this.cara2 = false});

  final double size;
  final bool cara2;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      cara2 ? semillaCara2Asset : semillaAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, _, __) => Icon(
        Icons.paid_rounded,
        size: size,
        color: const Color(0xFFE3AB5B),
      ),
    );
  }
}

/// Texto con el icono de semilla delante: "◈ 120" para mostrar saldos/cantidades.
class SemillaAmount extends StatelessWidget {
  const SemillaAmount({
    super.key,
    required this.amount,
    this.size = 18,
    this.style,
    this.prefix = '',
  });

  final num amount;
  final double size;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SemillaIcon(size: size),
        const SizedBox(width: 6),
        Text('$prefix$amount', style: style),
      ],
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.codigo, required this.size});

  final String codigo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = codigo.isEmpty ? '—' : codigo;
    final fontSize = label.length >= 4
        ? size * 0.24
        : label.length == 3
            ? size * 0.3
            : size * 0.42;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A3F52), Color(0xFF1B1D29)],
        ),
        border: Border.all(color: const Color(0xFFE3AB5B), width: 1.4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
