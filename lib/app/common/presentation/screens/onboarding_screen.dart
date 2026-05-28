import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../../blocs/app_session/app_session_cubit.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.charcoal : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -28,
                    top: -24,
                    child: Icon(
                      page.icon,
                      size: 180,
                      color: page.color.withValues(alpha: 0.16),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 156,
                      height: 156,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(page.icon, size: 78, color: page.color),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.03,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(
                alpha: 0.72,
              ),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: size * 0.35,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icons/cubnex_icon.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

const _pages = [
  _OnboardingContent(
    title: 'Explora mercados y servicios',
    description:
        'Encuentra productos, negocios, propiedades, transporte y servicios desde un solo marketplace movil.',
    icon: Icons.travel_explore_rounded,
    color: AppColors.gold,
  ),
  _OnboardingContent(
    title: 'Conecta tu negocio',
    description:
        'Crea tu tienda, personaliza marca, publica inventario y conecta con clientes o aliados comerciales.',
    icon: Icons.handshake_rounded,
    color: AppColors.blue,
  ),
  _OnboardingContent(
    title: 'Gestiona con inteligencia',
    description:
        'Usa scanner, IA, mapas y paneles para administrar productos, ofertas y pedidos con menos esfuerzo.',
    icon: Icons.auto_awesome_rounded,
    color: AppColors.green,
  ),
  _OnboardingContent(
    title: 'Impacto y recompensas',
    description:
        'Gana puntos, participa en promociones y fideliza clientes con sorteos, cashback y beneficios.',
    icon: Icons.emoji_events_rounded,
    color: AppColors.warning,
  ),
];
