import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/presentation/widgets/market_cards.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/home/home_cubit.dart';
import '../../blocs/home/home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeCubit>()..loadHome(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSessionCubit>().state;

    return Scaffold(
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final isLoading = state.status == HomeStatus.loading;

          return RefreshIndicator(
            onRefresh: () => context.read<HomeCubit>().loadHome(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _SearchHero(sessionLabel: _sessionLabel(session)),
                const SizedBox(height: 18),
                if (state.errorMessage != null)
                  _InlineWarning(message: state.errorMessage!),
                if (state.errorMessage != null) const SizedBox(height: 18),
                SectionHeader(
                  title: 'Promociones',
                  onAction: () => context.go(AppRoutes.promotions),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 178,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.banners.isEmpty ? 2 : state.banners.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (state.banners.isEmpty) {
                        return PromoBannerCard(
                          title: index == 0
                              ? 'Impulsa tu tienda'
                              : 'Encuentra negocios cerca',
                          subtitle: index == 0
                              ? 'Productos, servicios, QR y promociones.'
                              : 'Busca por provincia, mapa o scanner.',
                        );
                      }

                      final banner = state.banners[index];
                      return PromoBannerCard(
                        title: banner.title,
                        subtitle: banner.subtitle,
                        imageUrl: banner.imageUrl,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Categorias populares',
                  onAction: () => context.go(AppRoutes.search),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categories
                      .map(
                        (category) => CategoryChipCard(
                          label: category.label,
                          icon: category.icon,
                          onTap: () => context.go(AppRoutes.search),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    QuickActionCard(
                      title: 'Escanear',
                      subtitle: 'QR, etiqueta o codigo.',
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: () => context.go(AppRoutes.scanner),
                    ),
                    QuickActionCard(
                      title: 'Ver mapa',
                      subtitle: 'Negocios cercanos.',
                      icon: Icons.map_rounded,
                      onTap: () => context.go(AppRoutes.map),
                    ),
                    QuickActionCard(
                      title: 'Favoritos',
                      subtitle: 'Guarda tiendas y productos.',
                      icon: Icons.favorite_border_rounded,
                      onTap: () => context.go(AppRoutes.profile),
                    ),
                    QuickActionCard(
                      title: 'Propiedades',
                      subtitle: 'Casas y autos.',
                      icon: Icons.home_work_rounded,
                      onTap: () => context.go(AppRoutes.properties),
                    ),
                    QuickActionCard(
                      title: 'Transporte',
                      subtitle: 'Carga y delivery.',
                      icon: Icons.local_shipping_rounded,
                      onTap: () => context.go(AppRoutes.transport),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Negocios para visitar',
                  onAction: () => context.go(AppRoutes.search),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 178,
                  child: isLoading && state.businesses.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.businesses.isEmpty
                              ? _fallbackBusinesses.length
                              : state.businesses.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            if (state.businesses.isEmpty) {
                              final business = _fallbackBusinesses[index];
                              return BusinessPreviewCard(
                                name: business.name,
                                province: business.province,
                                description: business.description,
                              );
                            }

                            final business = state.businesses[index];
                            return BusinessPreviewCard(
                              name: business.name,
                              province: business.province,
                              description: business.description,
                              logoUrl: business.logoUrl,
                              rating: business.rating,
                              onTap: () => context.go(AppRoutes.store(business.id)),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Productos destacados',
                  onAction: () => context.go(AppRoutes.search),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 238,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.products.isEmpty
                        ? _fallbackProducts.length
                        : state.products.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (state.products.isEmpty) {
                        final product = _fallbackProducts[index];
                        return ProductPreviewCard(
                          name: product.name,
                          brand: product.brand,
                          price: product.price,
                          currency: product.currency,
                        );
                      }

                      final product = state.products[index];
                      return ProductPreviewCard(
                        name: product.name,
                        brand: product.brand,
                        imageUrl: product.imageUrl,
                        price: product.currentPrice,
                        currency: product.currency,
                        onTap: () => context.go(AppRoutes.product(product.id)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _SellerCta(
                  onCreateBusiness: () => context.go(AppRoutes.businessWizard),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _sessionLabel(AppSessionState session) {
    if (session.isBusiness) return 'Modo negocio activo';
    if (session.status == AppSessionStatus.authenticated) {
      return 'Cliente registrado';
    }
    return 'Explorando como invitado';
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero({required this.sessionLabel});

  final String sessionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sessionLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Compra, busca servicios y visita negocios cubanos desde el movil.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.06,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go(AppRoutes.search),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Productos, servicios, propiedades...',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.tune_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerCta extends StatelessWidget {
  const _SellerCta({required this.onCreateBusiness});

  final VoidCallback onCreateBusiness;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.gold
            : AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vende en CubNex',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.ink
                  : Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea tu tienda, personaliza colores y administra inventario desde la app.',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.ink.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreateBusiness,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Crear negocio'),
          ),
        ],
      ),
    );
  }
}

class _CategoryInfo {
  const _CategoryInfo(this.label, this.icon);

  final String label;
  final IconData icon;
}

const _categories = [
  _CategoryInfo('Alimentos', Icons.shopping_basket_rounded),
  _CategoryInfo('Transporte', Icons.local_shipping_rounded),
  _CategoryInfo('Servicios', Icons.handyman_rounded),
  _CategoryInfo('Propiedades', Icons.home_work_rounded),
  _CategoryInfo('Vehiculos', Icons.directions_car_rounded),
  _CategoryInfo('Gastronomia', Icons.restaurant_rounded),
];

const _fallbackBusinesses = [
  _FallbackBusiness(
    name: 'Tienda local',
    province: 'La Habana',
    description: 'Productos y ofertas para clientes cercanos.',
  ),
  _FallbackBusiness(
    name: 'Delivery urbano',
    province: 'Santiago de Cuba',
    description: 'Traslados, mensajeria y entregas por zonas.',
  ),
  _FallbackBusiness(
    name: 'Casa en venta',
    province: 'Matanzas',
    description: 'Propiedades, alquileres y anuncios destacados.',
  ),
];

const _fallbackProducts = [
  _FallbackProduct(
    name: 'Producto destacado',
    brand: 'CubNex',
    price: 0,
    currency: 'CUP',
  ),
  _FallbackProduct(
    name: 'Oferta del dia',
    brand: 'Tienda local',
    price: 0,
    currency: 'CUP',
  ),
  _FallbackProduct(
    name: 'Servicio recomendado',
    brand: 'Negocio verificado',
    price: 0,
    currency: 'CUP',
  ),
];

class _FallbackBusiness {
  const _FallbackBusiness({
    required this.name,
    this.province,
    this.description,
  });

  final String name;
  final String? province;
  final String? description;
  String? get logoUrl => null;
  double? get rating => null;
}

class _FallbackProduct {
  const _FallbackProduct({
    required this.name,
    this.brand,
    this.price,
    this.currency,
  });

  final String name;
  final String? brand;
  final double? price;
  final String? currency;
}
