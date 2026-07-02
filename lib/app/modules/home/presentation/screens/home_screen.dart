import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/presentation/widgets/market_cards.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/home/home_cubit.dart';
import '../../blocs/home/home_state.dart';
import '../../data/models/banner_model.dart';
import '../../../jobs/data/models/job_model.dart';

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

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 420) return;
    final cubit = context.read<HomeCubit>();
    cubit.loadMoreBusinesses();
    cubit.loadMoreProducts();
  }

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
              controller: _scrollController,
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
                  height: 188,
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
                        onTap: () => _openPromotion(context, banner),
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
                SizedBox(
                  height: 120,
                  child: _PopularCategoriesTicker(
                    onCategory: (category) => context.go(
                      Uri(
                        path: AppRoutes.search,
                        queryParameters: {'q': category.query},
                      ).toString(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Explora a tu manera'),
                const SizedBox(height: 12),
                _DiscoverySections(
                  onSearch: (query) => context.go(
                    Uri(
                      path: AppRoutes.search,
                      queryParameters: {'q': query},
                    ).toString(),
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Empleos cerca',
                  onAction: () => context.go(AppRoutes.jobs),
                ),
                const SizedBox(height: 12),
                _JobsStrip(
                  jobs: state.jobs,
                  onOpen: () => context.go(AppRoutes.jobs),
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Negocios para visitar',
                  onAction: () => context.go(AppRoutes.search),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 242,
                  child: isLoading && state.businesses.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.businesses.isEmpty
                              ? _fallbackBusinesses.length
                              : state.businesses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
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
                              bannerUrl: business.bannerUrl,
                              rating: business.rating,
                              availableNow: business.availableNow,
                              requiresElectricity: business.requiresElectricity,
                              hasElectricService: business.hasElectricService,
                              onTap: () =>
                                  context.go(AppRoutes.store(business.id)),
                            );
                          },
                        ),
                ),
                if (state.loadingMoreBusinesses)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(child: CircularProgressIndicator()),
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
                        rating: product.rating,
                        onTap: () => context.go(AppRoutes.product(product.id)),
                      );
                    },
                  ),
                ),
                if (state.loadingMoreProducts)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(child: CircularProgressIndicator()),
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

  void _openPromotion(BuildContext context, BannerModel banner) {
    final businessId = banner.businessId;
    if (businessId != null && businessId.isNotEmpty) {
      context.go(AppRoutes.store(businessId));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              banner.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (banner.subtitle != null && banner.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(banner.subtitle!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoutes.promotions);
              },
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Ver promociones'),
            ),
          ],
        ),
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
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.go(AppRoutes.search),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Buscar con la camara',
                child: Material(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go(AppRoutes.scanner),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: Icon(
                        Icons.document_scanner_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscoverySections extends StatelessWidget {
  const _DiscoverySections({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DiscoveryInfo(
        eyebrow: 'Hoy',
        title: 'Para comer hoy',
        subtitle: 'Restaurantes, bares, cafeterias y cartas QR.',
        color: AppColors.gold,
        query: 'gastronomia restaurante bar cafeteria carta menu',
      ),
      _DiscoveryInfo(
        eyebrow: 'Servicios',
        title: 'Servicios rapidos',
        subtitle: 'Plomeria, barberia, reparaciones y profesionales.',
        color: AppColors.green,
        query: 'servicio reparacion barberia plomeria',
      ),
      _DiscoveryInfo(
        eyebrow: 'Ahorra',
        title: 'Ofertas cerca',
        subtitle: 'Promociones, cashback y productos destacados.',
        color: AppColors.warning,
        query: 'oferta promocion descuento',
      ),
      _DiscoveryInfo(
        eyebrow: 'Rutas',
        title: 'Mover o enviar',
        subtitle: 'Delivery, carga, taxi, mudanzas y rutas.',
        color: AppColors.blue,
        query: 'transporte delivery taxi carga',
      ),
    ];

    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _DiscoveryCard(item: item, onTap: () => onSearch(item.query));
        },
      ),
    );
  }
}

class _JobsStrip extends StatelessWidget {
  const _JobsStrip({required this.jobs, required this.onOpen});

  final List<JobModel> jobs;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.work_outline_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Marca en tu perfil que buscas empleo y revisa nuevas oportunidades publicadas por negocios.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final job = jobs[index];
          return SizedBox(
            width: 254,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              job.businessName ?? 'Negocio',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Text(
                        job.salaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PopularCategoriesTicker extends StatefulWidget {
  const _PopularCategoriesTicker({required this.onCategory});

  final ValueChanged<_CategoryInfo> onCategory;

  @override
  State<_PopularCategoriesTicker> createState() =>
      _PopularCategoriesTickerState();
}

class _PopularCategoriesTickerState extends State<_PopularCategoriesTicker> {
  final _controller = ScrollController();
  Timer? _timer;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTicker());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTicker() {
    if (!mounted || _timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 28), (_) {
      if (!_controller.hasClients || _userScrolling) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _controller.offset + 0.42;
      if (next >= max - 1) {
        _controller.jumpTo(0);
        return;
      }
      _controller.jumpTo(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loop = List<_CategoryInfo>.generate(
      _categories.length * 6,
      (index) => _categories[index % _categories.length],
    );
    final top = [
      for (var index = 0; index < loop.length; index += 2) loop[index],
    ];
    final bottom = [
      for (var index = 1; index < loop.length; index += 2) loop[index],
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 128),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification) {
            _userScrolling = notification.direction != ScrollDirection.idle;
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryTickerRow(
                  categories: top,
                  onCategory: widget.onCategory,
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 82),
                  child: _CategoryTickerRow(
                    categories: bottom,
                    onCategory: widget.onCategory,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTickerRow extends StatelessWidget {
  const _CategoryTickerRow({
    required this.categories,
    required this.onCategory,
  });

  final List<_CategoryInfo> categories;
  final ValueChanged<_CategoryInfo> onCategory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final category in categories) ...[
          CategoryChipCard(
            label: category.label,
            icon: category.icon,
            onTap: () => onCategory(category),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({required this.item, required this.onTap});

  final _DiscoveryInfo item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 230,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.eyebrow,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryInfo {
  const _DiscoveryInfo({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.query,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color color;
  final String query;
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
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
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
  const _CategoryInfo(this.label, this.icon, this.query);

  final String label;
  final IconData icon;
  final String query;
}

const _categories = [
  _CategoryInfo('Alimentos', Icons.shopping_basket_rounded, 'alimentos'),
  _CategoryInfo(
    'Transporte',
    Icons.local_shipping_rounded,
    'transporte delivery carga taxi',
  ),
  _CategoryInfo(
    'Servicios',
    Icons.handyman_rounded,
    'servicios plomeria barberia reparacion',
  ),
  _CategoryInfo(
    'Propiedades',
    Icons.home_work_rounded,
    'propiedades casas alquiler',
  ),
  _CategoryInfo(
    'Vehiculos',
    Icons.directions_car_rounded,
    'vehiculos autos motos renta',
  ),
  _CategoryInfo(
    'Gastronomia',
    Icons.restaurant_rounded,
    'gastronomia restaurante cafeteria bar menu',
  ),
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
