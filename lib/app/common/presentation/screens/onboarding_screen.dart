import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../../blocs/app_session/app_session_cubit.dart';
import '../widgets/cubnex_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            children: [
              Row(
                children: [
                  const _BrandMark(size: 48),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CubNex',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          'Conecta tu Mundo',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _goLogin,
                    child: const Text('Saltar'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (_, index) => _OnboardingPage(page: _pages[index]),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _index == index ? 26 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _index == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _index == _pages.length - 1 ? _goLogin : _next,
                child: Text(_index == _pages.length - 1 ? 'Comenzar' : 'Siguiente'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _continueAsGuest,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explorar como invitado'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goLogin() async {
    await context.read<AppSessionCubit>().markOnboardingSeen();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _continueAsGuest() async {
    await context.read<AppSessionCubit>().continueAsGuest();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final _OnboardingContent page;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: page.color.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: page.color.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _OnboardingScene(page: page),
          ),
          const SizedBox(height: 22),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.03,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CubNexLogo(size: size);
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.scene,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final _OnboardingSceneType scene;
}

enum _OnboardingSceneType { market, business, intelligence, rewards }

class _OnboardingScene extends StatelessWidget {
  const _OnboardingScene({required this.page});

  final _OnboardingContent page;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              page.color.withValues(alpha: 0.18),
              AppColors.darkBackground,
              const Color(0xFF0A1015),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _OnboardingScenePainter(page),
          child: const SizedBox(width: double.infinity, height: double.infinity),
        ),
      ),
    );
  }
}

class _OnboardingScenePainter extends CustomPainter {
  const _OnboardingScenePainter(this.page);

  final _OnboardingContent page;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawIllustrationFrame(canvas, size);

    switch (page.scene) {
      case _OnboardingSceneType.market:
        _drawMarketScene(canvas, size);
      case _OnboardingSceneType.business:
        _drawBusinessScene(canvas, size);
      case _OnboardingSceneType.intelligence:
        _drawIntelligenceScene(canvas, size);
      case _OnboardingSceneType.rewards:
        _drawRewardsScene(canvas, size);
    }
  }

  Rect _illustrationRect(Size size) {
    final width = math.min(size.width * 0.86, 310.0);
    final height = size.height * 0.82;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);
    for (var x = -size.width; x < size.width * 2; x += 32) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height * 0.35, size.height),
        grid,
      );
    }
    for (var y = 18.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final glow = Paint()
      ..color = page.color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawCircle(Offset(size.width * 0.54, size.height * 0.44), 90, glow);
  }

  void _drawIllustrationFrame(Canvas canvas, Size size) {
    final rect = _illustrationRect(size);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.44)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 8)), const Radius.circular(28)),
      shadow,
    );

    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF081012),
          page.color.withValues(alpha: 0.1),
          const Color(0xFF111816),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      body,
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(30)),
      stroke,
    );
  }

  void _drawMarketScene(Canvas canvas, Size size) {
    final rect = _illustrationRect(size).deflate(24);
    _drawSceneAccent(canvas, rect, AppColors.gold);

    final mapCenter = Offset(rect.center.dx, rect.center.dy + rect.height * 0.03);
    final map = Path()
      ..moveTo(mapCenter.dx, mapCenter.dy - 58)
      ..lineTo(mapCenter.dx + 84, mapCenter.dy - 4)
      ..lineTo(mapCenter.dx, mapCenter.dy + 54)
      ..lineTo(mapCenter.dx - 84, mapCenter.dy - 4)
      ..close();
    canvas.drawPath(map, Paint()..color = AppColors.blue.withValues(alpha: 0.15));
    canvas.drawPath(
      map,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    for (final dx in [-42.0, 0.0, 42.0]) {
      canvas.drawLine(
        Offset(mapCenter.dx + dx, mapCenter.dy - 32),
        Offset(mapCenter.dx + dx, mapCenter.dy + 34),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.13),
      );
    }

    _drawPin(canvas, Offset(mapCenter.dx - 44, mapCenter.dy - 18), Icons.storefront_rounded);
    _drawPin(canvas, Offset(mapCenter.dx + 18, mapCenter.dy - 28), Icons.restaurant_rounded);
    _drawPin(canvas, Offset(mapCenter.dx + 48, mapCenter.dy + 18), Icons.handyman_rounded);
    _drawMiniBadge(canvas, Offset(rect.left + 48, rect.bottom - 52), Icons.shopping_bag_rounded);
    _drawMiniBadge(canvas, Offset(rect.right - 48, rect.bottom - 52), Icons.design_services_rounded);
    _drawMiniBadge(canvas, Offset(rect.center.dx, rect.bottom - 94), Icons.location_searching_rounded);
  }

  void _drawBusinessScene(Canvas canvas, Size size) {
    final rect = _illustrationRect(size).deflate(24);
    _drawSceneAccent(canvas, rect, AppColors.blue);

    _drawIcon(canvas, Icons.handshake_rounded, Offset(rect.center.dx, rect.center.dy + 8), AppColors.gold, 72);
    final nodes = [
      Offset(rect.center.dx - 82, rect.center.dy - 18),
      Offset(rect.center.dx - 48, rect.center.dy + 68),
      Offset(rect.center.dx + 70, rect.center.dy - 46),
      Offset(rect.center.dx + 86, rect.center.dy + 50),
    ];
    for (final node in nodes) {
      canvas.drawLine(
        Offset(rect.center.dx, rect.center.dy + 8),
        node,
        Paint()
          ..strokeWidth = 1.6
          ..color = AppColors.blue.withValues(alpha: 0.62),
      );
      canvas.drawCircle(node, 18, Paint()..color = const Color(0xFF102036));
      canvas.drawCircle(
        node,
        18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.gold.withValues(alpha: 0.72),
      );
    }
    _drawIcon(canvas, Icons.inventory_2_outlined, nodes[0], AppColors.gold, 20);
    _drawIcon(canvas, Icons.campaign_outlined, nodes[1], AppColors.blue, 20);
    _drawIcon(canvas, Icons.groups_rounded, nodes[2], AppColors.greenLight, 20);
    _drawIcon(canvas, Icons.qr_code_rounded, nodes[3], AppColors.gold, 20);
  }

  void _drawIntelligenceScene(Canvas canvas, Size size) {
    final rect = _illustrationRect(size).deflate(24);
    _drawSceneAccent(canvas, rect, AppColors.green);

    final tablet = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.center.dy + 18),
        width: rect.width * 0.82,
        height: rect.height * 0.38,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(tablet, Paint()..color = const Color(0xFF142028));
    canvas.drawRRect(
      tablet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.greenLight.withValues(alpha: 0.78),
    );
    _drawIcon(canvas, Icons.auto_awesome_rounded, Offset(tablet.outerRect.right - 34, tablet.outerRect.top + 32), AppColors.greenLight, 28);
    _drawIcon(canvas, Icons.memory_rounded, Offset(tablet.outerRect.left + 38, tablet.outerRect.top + 34), AppColors.gold, 30);
    _drawChartLine(canvas, tablet.outerRect.deflate(22));

    final top = tablet.outerRect.top - 58;
    for (var i = 0; i < 4; i++) {
      final x = rect.left + 32 + i * 46;
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top + (i.isEven ? 0 : 14), 34, 30),
        const Radius.circular(8),
      );
      canvas.drawRRect(box, Paint()..color = Colors.white.withValues(alpha: 0.1));
      canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.22),
      );
      canvas.drawLine(
        Offset(x + 17, box.outerRect.bottom),
        Offset(tablet.outerRect.center.dx, tablet.outerRect.top),
        Paint()
          ..strokeWidth = 1
          ..color = AppColors.greenLight.withValues(alpha: 0.28),
      );
    }
  }

  void _drawRewardsScene(Canvas canvas, Size size) {
    final rect = _illustrationRect(size).deflate(24);
    _drawSceneAccent(canvas, rect, AppColors.warning);

    final base = rect.bottom - 48;
    final left = rect.left + 24;
    for (var i = 0; i < 5; i++) {
      final h = 34.0 + i * 18;
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + i * 28, base - h, 18, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(bar, Paint()..color = AppColors.gold.withValues(alpha: 0.78));
    }
    _drawIcon(canvas, Icons.emoji_events_rounded, Offset(rect.center.dx, rect.top + 88), AppColors.gold, 58);

    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.right - 88, rect.center.dy - 8, 76, 94),
      const Radius.circular(16),
    );
    canvas.drawRRect(card, Paint()..color = const Color(0xFF162033));
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.gold.withValues(alpha: 0.72),
    );
    _drawIcon(canvas, Icons.person_rounded, Offset(card.outerRect.center.dx, card.outerRect.top + 26), AppColors.gold, 28);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(card.outerRect.left + 16, card.outerRect.top + 52 + i * 12, 44 - i * 8, 5),
          const Radius.circular(99),
        ),
        Paint()..color = i == 0 ? AppColors.greenLight : Colors.white.withValues(alpha: 0.26),
      );
    }

    for (var i = 0; i < 4; i++) {
      _drawIcon(canvas, Icons.star_rounded, Offset(rect.left + 30 + i * 24, rect.top + 54), AppColors.gold, 18);
    }
  }

  void _drawSceneAccent(Canvas canvas, Rect rect, Color color) {
    canvas.drawLine(
      Offset(rect.left + 8, rect.top + 18),
      Offset(rect.left + 108, rect.top + 18),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = color,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(rect.right - 20 - i * 18, rect.top + 18),
        4,
        Paint()..color = color.withValues(alpha: 0.9 - i * 0.22),
      );
    }
  }

  void _drawPin(Canvas canvas, Offset point, IconData icon) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: point, radius: 20))
      ..moveTo(point.dx - 8, point.dy + 16)
      ..lineTo(point.dx, point.dy + 36)
      ..lineTo(point.dx + 8, point.dy + 16)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.gold);
    _drawIcon(canvas, icon, point, const Color(0xFF071012), 19);
  }

  void _drawMiniBadge(Canvas canvas, Offset center, IconData icon) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 62, height: 46),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF13202B));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.gold.withValues(alpha: 0.5),
    );
    _drawIcon(canvas, icon, center, AppColors.gold, 22);
  }

  void _drawChartLine(Canvas canvas, Rect rect) {
    final path = Path()
      ..moveTo(rect.left, rect.bottom - 14)
      ..cubicTo(rect.left + 34, rect.bottom - 8, rect.left + 46, rect.top + 38, rect.left + 74, rect.top + 46)
      ..cubicTo(rect.left + 102, rect.top + 54, rect.left + 112, rect.top + 14, rect.right, rect.top + 18);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.greenLight,
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
  bool shouldRepaint(covariant _OnboardingScenePainter oldDelegate) {
    return oldDelegate.page != page;
  }
}

const _pages = [
  _OnboardingContent(
    title: 'Explora mercados y servicios',
    description:
        'Encuentra productos, negocios, propiedades, transporte y servicios desde un solo marketplace movil.',
    icon: Icons.travel_explore_rounded,
    color: AppColors.gold,
    scene: _OnboardingSceneType.market,
  ),
  _OnboardingContent(
    title: 'Conecta tu negocio',
    description:
        'Crea tu tienda, personaliza marca, publica inventario y conecta con clientes o aliados comerciales.',
    icon: Icons.handshake_rounded,
    color: AppColors.blue,
    scene: _OnboardingSceneType.business,
  ),
  _OnboardingContent(
    title: 'Gestiona con inteligencia',
    description:
        'Usa scanner, IA, mapas y paneles para administrar productos, ofertas y pedidos con menos esfuerzo.',
    icon: Icons.auto_awesome_rounded,
    color: AppColors.green,
    scene: _OnboardingSceneType.intelligence,
  ),
  _OnboardingContent(
    title: 'Impacto y recompensas',
    description:
        'Gana puntos, participa en promociones y fideliza clientes con sorteos, cashback y beneficios.',
    icon: Icons.emoji_events_rounded,
    color: AppColors.warning,
    scene: _OnboardingSceneType.rewards,
  ),
];
