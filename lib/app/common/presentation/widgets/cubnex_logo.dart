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
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = 0.96 + math.sin(animation.value * math.pi * 2) * 0.035;

        return Transform.scale(
          scale: pulse,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CubNexLogo(size: size, showGlow: true),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LogoConnectionPainter(progress: animation.value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogoConnectionPainter extends CustomPainter {
  const _LogoConnectionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.43;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.012
      ..color = AppColors.greenLight.withValues(alpha: 0.46);
    canvas.drawCircle(center, radius * (0.94 + progress * 0.08), ringPaint);

    final nodes = List.generate(6, (index) {
      final angle = (math.pi * 2 * index / 6) + (progress * math.pi * 2);
      return Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
    });

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.shortestSide * 0.01
      ..color = AppColors.gold.withValues(alpha: 0.38);

    for (var i = 0; i < nodes.length; i++) {
      canvas.drawLine(nodes[i], nodes[(i + 2) % nodes.length], linePaint);
    }

    for (var i = 0; i < nodes.length; i++) {
      final active = ((progress * nodes.length).floor() % nodes.length) == i;
      final nodePaint = Paint()
        ..color = (i.isEven ? AppColors.gold : AppColors.greenLight)
            .withValues(alpha: active ? 1 : 0.78);
      canvas.drawCircle(
        nodes[i],
        size.shortestSide * (active ? 0.03 : 0.022),
        nodePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoConnectionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
