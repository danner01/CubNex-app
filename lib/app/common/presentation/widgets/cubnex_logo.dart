import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class CubNexLogo extends StatelessWidget {
  const CubNexLogo({super.key, this.size = 96, this.showGlow = true});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: showGlow
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.26),
                    blurRadius: size * 0.24,
                  ),
                  BoxShadow(
                    color: AppColors.greenLight.withValues(alpha: 0.18),
                    blurRadius: size * 0.34,
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/cubnex_icon.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class AnimatedCubNexLogo extends StatelessWidget {
  const AnimatedCubNexLogo({
    super.key,
    required this.animation,
    this.size = 132,
  });

  final Animation<double> animation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final pulse = 0.97 + math.sin(animation.value * math.pi * 2) * 0.028;
          return Transform.scale(
            scale: pulse,
            child: CustomPaint(
              painter: _AnimatedCubNexBadgePainter(progress: animation.value),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedCubNexBadgePainter extends CustomPainter {
  const _AnimatedCubNexBadgePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.48;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glow = Paint()
      ..color = AppColors.greenLight.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius * 1.02, glow);

    final fill = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.35),
        radius: 0.95,
        colors: [Color(0xFF26322A), Color(0xFF07100F), Color(0xFF020303)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, fill);

    final outerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.045
      ..shader = SweepGradient(
        colors: const [
          AppColors.goldDark,
          Color(0xFFFFE68C),
          AppColors.greenLight,
          AppColors.gold,
          AppColors.goldDark,
        ],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect);
    canvas.drawCircle(center, radius * 0.96, outerRing);

    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.008
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(center, radius * 0.76, innerRing);

    _drawCuba(canvas, center, radius);
    _drawConnections(canvas, center, radius);
    _drawBrandText(canvas, center, radius);
  }

  void _drawCuba(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx - radius * 0.58, center.dy - radius * 0.26)
      ..cubicTo(
        center.dx - radius * 0.36,
        center.dy - radius * 0.42,
        center.dx - radius * 0.12,
        center.dy - radius * 0.36,
        center.dx + radius * 0.1,
        center.dy - radius * 0.28,
      )
      ..cubicTo(
        center.dx + radius * 0.35,
        center.dy - radius * 0.2,
        center.dx + radius * 0.55,
        center.dy - radius * 0.13,
        center.dx + radius * 0.68,
        center.dy - radius * 0.04,
      )
      ..cubicTo(
        center.dx + radius * 0.44,
        center.dy - radius * 0.02,
        center.dx + radius * 0.13,
        center.dy - radius * 0.02,
        center.dx - radius * 0.16,
        center.dy + radius * 0.07,
      )
      ..cubicTo(
        center.dx - radius * 0.35,
        center.dy + radius * 0.14,
        center.dx - radius * 0.58,
        center.dy + radius * 0.03,
        center.dx - radius * 0.58,
        center.dy - radius * 0.26,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = AppColors.greenLight.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.02
        ..color = AppColors.gold.withValues(alpha: 0.7),
    );
  }

  void _drawConnections(Canvas canvas, Offset center, double radius) {
    final nodes = [
      _LogoNode(
        Offset(center.dx - radius * 0.48, center.dy - radius * 0.2),
        Icons.storefront_rounded,
        AppColors.gold,
      ),
      _LogoNode(
        Offset(center.dx - radius * 0.12, center.dy - radius * 0.42),
        Icons.restaurant_rounded,
        AppColors.greenLight,
      ),
      _LogoNode(
        Offset(center.dx + radius * 0.42, center.dy - radius * 0.24),
        Icons.local_shipping_rounded,
        AppColors.gold,
      ),
      _LogoNode(
        Offset(center.dx + radius * 0.5, center.dy + radius * 0.24),
        Icons.qr_code_2_rounded,
        AppColors.greenLight,
      ),
      _LogoNode(
        Offset(center.dx + radius * 0.04, center.dy + radius * 0.5),
        Icons.location_on_rounded,
        AppColors.gold,
      ),
      _LogoNode(
        Offset(center.dx - radius * 0.46, center.dy + radius * 0.28),
        Icons.shopping_bag_rounded,
        AppColors.greenLight,
      ),
    ];

    final baseLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.014
      ..color = AppColors.greenLight.withValues(alpha: 0.24);
    final activeLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.022
      ..color = AppColors.gold.withValues(alpha: 0.78);

    for (var i = 0; i < nodes.length; i++) {
      final start = nodes[i].point;
      final end = nodes[(i + 1) % nodes.length].point;
      canvas.drawLine(start, end, baseLine);

      final phase = (progress + i / nodes.length) % 1;
      final pulseStart = Offset.lerp(start, end, phase)!;
      final pulseEnd = Offset.lerp(start, end, math.min(phase + 0.18, 1))!;
      canvas.drawLine(pulseStart, pulseEnd, activeLine);
    }

    for (var i = 0; i < nodes.length; i++) {
      final active = ((progress * nodes.length).floor() % nodes.length) == i;
      final nodePaint = Paint()
        ..color = nodes[i].color.withValues(alpha: active ? 1 : 0.88);
      canvas.drawCircle(nodes[i].point, radius * (active ? 0.095 : 0.078), nodePaint);
      canvas.drawCircle(
        nodes[i].point,
        radius * (active ? 0.122 : 0.096),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.014
          ..color = Colors.white.withValues(alpha: active ? 0.34 : 0.18),
      );
      _drawIcon(canvas, nodes[i].icon, nodes[i].point, Colors.black.withValues(alpha: 0.82), radius * 0.1);
    }
  }

  void _drawBrandText(Canvas canvas, Offset center, double radius) {
    final baseline = center.dy + radius * 0.18;
    final cubStyle = TextStyle(
      color: AppColors.gold,
      fontSize: radius * 0.43,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(1, 2))],
    );
    final exStyle = cubStyle.copyWith(color: AppColors.greenLight);

    final cub = TextPainter(
      text: TextSpan(text: 'Cub', style: cubStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final ex = TextPainter(
      text: TextSpan(text: 'ex', style: exStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalWidth = cub.width + radius * 0.34 + ex.width - radius * 0.08;
    var x = center.dx - totalWidth / 2;
    cub.paint(canvas, Offset(x, baseline - cub.height));
    x += cub.width - radius * 0.03;
    _drawHybridNA(canvas, Offset(x, baseline - radius * 0.42), radius);
    x += radius * 0.32;
    ex.paint(canvas, Offset(x, baseline - ex.height));
  }

  void _drawHybridNA(Canvas canvas, Offset origin, double radius) {
    final w = radius * 0.34;
    final h = radius * 0.48;
    final path = Path()
      ..moveTo(origin.dx, origin.dy + h)
      ..lineTo(origin.dx + w * 0.44, origin.dy)
      ..lineTo(origin.dx + w, origin.dy + h)
      ..lineTo(origin.dx + w * 0.78, origin.dy + h)
      ..lineTo(origin.dx + w * 0.62, origin.dy + h * 0.64)
      ..lineTo(origin.dx + w * 0.25, origin.dy + h * 0.64)
      ..lineTo(origin.dx + w * 0.12, origin.dy + h)
      ..close();
    final bridge = Path()
      ..moveTo(origin.dx + w * 0.3, origin.dy + h * 0.5)
      ..lineTo(origin.dx + w * 0.57, origin.dy + h * 0.5);

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7FFFE0), AppColors.greenLight],
      ).createShader(Rect.fromLTWH(origin.dx, origin.dy, w, h));
    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.018
        ..color = AppColors.gold.withValues(alpha: 0.88),
    );
    canvas.drawPath(
      bridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.025
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold.withValues(alpha: 0.95),
    );
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset center, Color color, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          fontSize: size,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _AnimatedCubNexBadgePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LogoNode {
  const _LogoNode(this.point, this.icon, this.color);

  final Offset point;
  final IconData icon;
  final Color color;
}
