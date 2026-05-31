import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../widgets/cubnex_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _goToOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goToOnboarding() async {
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    context.go(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CubaNetworkPainter(progress: _controller.value),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: [
                      AppColors.gold.withValues(alpha: 0.14),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                    stops: const [0, 0.52, 1],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCubNexLogo(
                    animation: _controller,
                    size: 138,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'CubNex',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Conecta negocios, clientes y oportunidades',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.greenLight,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    width: 148,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: _controller.value,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CubaNetworkPainter extends CustomPainter {
  const _CubaNetworkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final mapRect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.2,
      size.width * 0.84,
      size.height * 0.32,
    );

    final mapPath = _buildCubaPath(mapRect);
    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.greenLight.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawPath(mapPath.shift(const Offset(0, 10)), shadowPaint);

    final mapFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.gold.withValues(alpha: 0.16),
          AppColors.green.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.05),
        ],
      ).createShader(mapRect);
    canvas.drawPath(mapPath, mapFill);

    final mapStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawPath(mapPath, mapStroke);

    final nodes = _nodes(size);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = AppColors.greenLight.withValues(alpha: 0.32);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..color = AppColors.gold.withValues(alpha: 0.72);

    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i].point, nodes[i + 1].point, linePaint);
      final phase = ((progress + i * 0.13) % 1.0);
      final start = Offset.lerp(nodes[i].point, nodes[i + 1].point, phase)!;
      final end = Offset.lerp(nodes[i].point, nodes[i + 1].point, math.min(phase + 0.12, 1))!;
      canvas.drawLine(start, end, activePaint);
    }

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final pulse = 0.5 + 0.5 * math.sin((progress * math.pi * 2) + i);
      final radius = 13 + pulse * 5;

      final halo = Paint()
        ..color = node.color.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(node.point, radius, halo);

      final fill = Paint()..color = const Color(0xFF121615);
      canvas.drawCircle(node.point, 15, fill);

      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = node.color.withValues(alpha: 0.9);
      canvas.drawCircle(node.point, 15, ring);

      _drawIcon(canvas, node.icon, node.point, node.color);
    }
  }

  Path _buildCubaPath(Rect rect) {
    Offset p(double x, double y) =>
        Offset(rect.left + rect.width * x, rect.top + rect.height * y);

    return Path()
      ..moveTo(p(0.02, 0.58).dx, p(0.02, 0.58).dy)
      ..cubicTo(p(0.18, 0.31).dx, p(0.18, 0.31).dy, p(0.42, 0.25).dx,
          p(0.42, 0.25).dy, p(0.66, 0.34).dx, p(0.66, 0.34).dy)
      ..cubicTo(p(0.83, 0.4).dx, p(0.83, 0.4).dy, p(0.94, 0.51).dx,
          p(0.94, 0.51).dy, p(0.98, 0.65).dx, p(0.98, 0.65).dy)
      ..cubicTo(p(0.72, 0.56).dx, p(0.72, 0.56).dy, p(0.44, 0.55).dx,
          p(0.44, 0.55).dy, p(0.2, 0.73).dx, p(0.2, 0.73).dy)
      ..cubicTo(p(0.08, 0.82).dx, p(0.08, 0.82).dy, p(-0.02, 0.74).dx,
          p(-0.02, 0.74).dy, p(0.02, 0.58).dx, p(0.02, 0.58).dy)
      ..close();
  }

  List<_NetworkNode> _nodes(Size size) {
    return [
      _NetworkNode(
        Offset(size.width * 0.18, size.height * 0.34),
        Icons.storefront_rounded,
        AppColors.gold,
      ),
      _NetworkNode(
        Offset(size.width * 0.34, size.height * 0.29),
        Icons.restaurant_rounded,
        AppColors.greenLight,
      ),
      _NetworkNode(
        Offset(size.width * 0.5, size.height * 0.36),
        Icons.local_shipping_rounded,
        AppColors.gold,
      ),
      _NetworkNode(
        Offset(size.width * 0.67, size.height * 0.31),
        Icons.home_work_rounded,
        AppColors.greenLight,
      ),
      _NetworkNode(
        Offset(size.width * 0.82, size.height * 0.42),
        Icons.qr_code_2_rounded,
        AppColors.gold,
      ),
      _NetworkNode(
        Offset(size.width * 0.72, size.height * 0.56),
        Icons.shopping_bag_rounded,
        AppColors.greenLight,
      ),
      _NetworkNode(
        Offset(size.width * 0.31, size.height * 0.54),
        Icons.location_on_rounded,
        AppColors.gold,
      ),
    ];
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset center, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          fontSize: 17,
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
  bool shouldRepaint(covariant _CubaNetworkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _NetworkNode {
  const _NetworkNode(this.point, this.icon, this.color);

  final Offset point;
  final IconData icon;
  final Color color;
}
