import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class ConKkaoLogo extends StatelessWidget {
  const ConKkaoLogo({super.key, this.size = 96, this.showGlow = true});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showGlow)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: size * 0.055,
                sigmaY: size * 0.055,
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  AppColors.gold.withValues(alpha: 0.72),
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/icons/conkkao_icon.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          Image.asset(
            'assets/icons/conkkao_icon.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    );
  }
}

class AnimatedConKkaoLogo extends StatelessWidget {
  const AnimatedConKkaoLogo({
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: size * 0.05,
                    sigmaY: size * 0.05,
                  ),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      AppColors.gold.withValues(alpha: 0.68),
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      'assets/icons/conkkao_icon.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Image.asset(
                  'assets/icons/conkkao_icon.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Kept for compatibility with older animated-logo callers.
// ignore: unused_element
class _AnimatedLogoOverlayPainter extends CustomPainter {
  const _AnimatedLogoOverlayPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.34;
    final points = [
      Offset(center.dx - radius * 0.7, center.dy - radius * 0.18),
      Offset(center.dx - radius * 0.1, center.dy - radius * 0.66),
      Offset(center.dx + radius * 0.62, center.dy - radius * 0.35),
      Offset(center.dx + radius * 0.64, center.dy + radius * 0.42),
      Offset(center.dx, center.dy + radius * 0.62),
      Offset(center.dx - radius * 0.62, center.dy + radius * 0.35),
    ];

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.009
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.2);
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.016
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gold.withValues(alpha: 0.86);

    for (var i = 0; i < points.length; i++) {
      final start = points[i];
      final end = points[(i + 1) % points.length];
      canvas.drawLine(start, end, base);
      final phase = (progress + i / points.length) % 1;
      final pulseStart = Offset.lerp(start, end, phase)!;
      final pulseEnd = Offset.lerp(start, end, math.min(phase + 0.16, 1))!;
      canvas.drawLine(pulseStart, pulseEnd, pulsePaint);
    }

    for (var i = 0; i < points.length; i++) {
      final active = ((progress * points.length).floor() % points.length) == i;
      canvas.drawCircle(
        points[i],
        size.shortestSide * (active ? 0.036 : 0.027),
        Paint()..color = AppColors.greenLight.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        points[i],
        size.shortestSide * 0.045,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.008
          ..color = Colors.white.withValues(alpha: active ? 0.62 : 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedLogoOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Kept as a compatibility painter for older callers while the asset-based
// branding is rolled out across all platforms.
// ignore: unused_element
class _AnimatedConKkaoBadgePainter extends CustomPainter {
  const _AnimatedConKkaoBadgePainter({required this.progress});

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

    _drawCacaoPod(canvas, center, radius);
    _drawConnections(canvas, center, radius);
    _drawBrandText(canvas, center, radius);
  }

  void _drawCacaoPod(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.58)
      ..cubicTo(
        center.dx + radius * 0.38,
        center.dy - radius * 0.42,
        center.dx + radius * 0.46,
        center.dy + radius * 0.15,
        center.dx,
        center.dy + radius * 0.58,
      )
      ..cubicTo(
        center.dx - radius * 0.46,
        center.dy + radius * 0.15,
        center.dx - radius * 0.38,
        center.dy - radius * 0.42,
        center.dx,
        center.dy - radius * 0.58,
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

    final seam = Path()
      ..moveTo(center.dx, center.dy - radius * 0.45)
      ..cubicTo(
        center.dx - radius * 0.12,
        center.dy - radius * 0.12,
        center.dx + radius * 0.12,
        center.dy + radius * 0.16,
        center.dx,
        center.dy + radius * 0.46,
      );
    canvas.drawPath(
      seam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.035
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold.withValues(alpha: 0.78),
    );

    for (var i = 0; i < 4; i++) {
      final beanCenter = Offset(
        center.dx + (i.isEven ? -1 : 1) * radius * 0.12,
        center.dy - radius * 0.18 + i * radius * 0.12,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: beanCenter,
          width: radius * 0.13,
          height: radius * 0.19,
        ),
        Paint()..color = AppColors.gold.withValues(alpha: 0.72),
      );
    }
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
      canvas.drawCircle(
        nodes[i].point,
        radius * (active ? 0.095 : 0.078),
        nodePaint,
      );
      canvas.drawCircle(
        nodes[i].point,
        radius * (active ? 0.122 : 0.096),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.014
          ..color = Colors.white.withValues(alpha: active ? 0.34 : 0.18),
      );
      _drawIcon(
        canvas,
        nodes[i].icon,
        nodes[i].point,
        Colors.black.withValues(alpha: 0.82),
        radius * 0.1,
      );
    }
  }

  void _drawBrandText(Canvas canvas, Offset center, double radius) {
    final baseline = center.dy + radius * 0.18;
    final brandStyle = TextStyle(
      color: AppColors.gold,
      fontSize: radius * 0.43,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(1, 2)),
      ],
    );
    final brand = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: 'Con', style: brandStyle),
          TextSpan(
            text: 'Kkao',
            style: brandStyle.copyWith(color: AppColors.greenLight),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    brand.paint(
      canvas,
      Offset(center.dx - brand.width / 2, baseline - brand.height),
    );
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    Color color,
    double size,
  ) {
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

    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedConKkaoBadgePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LogoNode {
  const _LogoNode(this.point, this.icon, this.color);

  final Offset point;
  final IconData icon;
  final Color color;
}
