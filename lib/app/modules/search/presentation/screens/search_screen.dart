import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/market_cards.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/search/search_cubit.dart';
import '../../blocs/search/search_state.dart';
import '../../data/models/search_results_model.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SearchCubit>(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _initialQueryApplied = false;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialQueryApplied) return;
    _initialQueryApplied = true;

    final query = GoRouterState.of(context).uri.queryParameters['q']?.trim();
    if (query == null || query.isEmpty) return;

    _controller.text = query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SearchCubit>().search(query);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 380) return;
    context.read<SearchCubit>().loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SearchBar(
                controller: _controller,
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  IconButton(
                    tooltip: 'Escanear',
                    onPressed: () => context.go(AppRoutes.scanner),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    onPressed: () =>
                        context.read<SearchCubit>().search(_controller.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
                hintText: 'Productos, servicios, negocios...',
                onSubmitted: context.read<SearchCubit>().search,
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Categorias'),
              const SizedBox(height: 12),
              _HierarchicalCategoryFilters(
                selectedId: _selectedCategoryId,
                onParent: _selectParentCategory,
                onSubcategory: (query) => _searchPreset(context, query),
              ),
              const SizedBox(height: 20),
              QuickActionCard(
                title: 'Vista de mapa',
                subtitle: 'Negocios y anuncios con ubicacion.',
                icon: Icons.map_rounded,
                onTap: () => context.go(AppRoutes.map),
              ),
              const SizedBox(height: 24),
              _SearchResults(state: state),
            ],
          );
        },
      ),
    );
  }

  void _searchPreset(BuildContext context, String query) {
    _controller.text = query;
    context.read<SearchCubit>().search(query);
  }

  void _selectParentCategory(_SearchCategory category) {
    setState(() {
      _selectedCategoryId = _selectedCategoryId == category.id
          ? null
          : category.id;
    });

    if (_selectedCategoryId != null) {
      _searchPreset(context, category.query);
    }
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == SearchStatus.initial) {
      return const _EmptySearchState(
        message:
            'Escribe una busqueda para encontrar negocios, productos y servicios.',
      );
    }

    if (state.status == SearchStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.status == SearchStatus.failure) {
      return _MessageCard(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo buscar',
        message: state.errorMessage ?? 'Intenta de nuevo.',
        color: AppColors.danger,
      );
    }

    if (state.results.isEmpty) {
      return _EmptySearchState(
        message: 'No encontramos resultados para "${state.query}".',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Resultados para "${state.query}"'),
        const SizedBox(height: 12),
        if (state.results.businesses.isNotEmpty) ...[
          const _MiniSectionTitle('Negocios'),
          const SizedBox(height: 10),
          SizedBox(
            height: 226,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.results.businesses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final business = state.results.businesses[index];
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
                  onTap: () => context.go(AppRoutes.store(business.id)),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (state.results.products.isNotEmpty) ...[
          const _MiniSectionTitle('Productos'),
          const SizedBox(height: 10),
          SizedBox(
            height: 238,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.results.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = state.results.products[index];
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
          const SizedBox(height: 18),
        ],
        if (state.results.properties.isNotEmpty) ...[
          const _MiniSectionTitle('Propiedades'),
          const SizedBox(height: 10),
          ..._spacedAssetTiles(
            context,
            state.results.properties,
            (asset) => AppRoutes.property(asset.id),
          ),
          const SizedBox(height: 18),
        ],
        if (state.results.transport.isNotEmpty) ...[
          const _MiniSectionTitle('Transporte'),
          const SizedBox(height: 10),
          ..._spacedAssetTiles(
            context,
            state.results.transport,
            (asset) => AppRoutes.transportService(asset.id),
          ),
        ],
        if (state.loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  List<Widget> _spacedAssetTiles(
    BuildContext context,
    List<SearchAssetModel> assets,
    String Function(SearchAssetModel asset) routeFor,
  ) {
    return [
      for (var index = 0; index < assets.length; index++) ...[
        _AssetResultTile(
          assets[index],
          onTap: () => context.go(routeFor(assets[index])),
        ),
        if (index < assets.length - 1) const SizedBox(height: 8),
      ],
    ];
  }
}

class _HierarchicalCategoryFilters extends StatelessWidget {
  const _HierarchicalCategoryFilters({
    required this.selectedId,
    required this.onParent,
    required this.onSubcategory,
  });

  final String? selectedId;
  final ValueChanged<_SearchCategory> onParent;
  final ValueChanged<String> onSubcategory;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final category in _searchCategories) ...[
                ChoiceChip(
                  selected: category.id == selectedId,
                  avatar: Icon(category.icon, size: 18),
                  label: Text(category.label),
                  onSelected: (_) => onParent(category),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (selected != null && selected.children.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final child in selected.children) ...[
                  CategoryChipCard(
                    label: child.label,
                    icon: child.icon,
                    onTap: () => onSubcategory(child.query),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  _SearchCategory? get _selectedCategory {
    for (final category in _searchCategories) {
      if (category.id == selectedId) return category;
    }
    return null;
  }
}

class _SearchCategory {
  const _SearchCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.query,
    this.children = const [],
  });

  final String id;
  final String label;
  final IconData icon;
  final String query;
  final List<_SearchCategory> children;
}

const _searchCategories = [
  _SearchCategory(
    id: 'negocios-servicios',
    label: 'Negocios y servicios',
    icon: Icons.storefront_rounded,
    query: 'servicio',
    children: [
      _SearchCategory(
        id: 'barberia',
        label: 'Barberias',
        icon: Icons.content_cut_rounded,
        query: 'barberia',
      ),
      _SearchCategory(
        id: 'plomeria',
        label: 'Plomeria',
        icon: Icons.plumbing_rounded,
        query: 'plomeria',
      ),
      _SearchCategory(
        id: 'electricista',
        label: 'Electricistas',
        icon: Icons.electrical_services_rounded,
        query: 'electricista',
      ),
      _SearchCategory(
        id: 'reparacion',
        label: 'Reparaciones',
        icon: Icons.build_rounded,
        query: 'reparacion',
      ),
    ],
  ),
  _SearchCategory(
    id: 'productos',
    label: 'Productos',
    icon: Icons.inventory_2_rounded,
    query: 'producto',
    children: [
      _SearchCategory(
        id: 'alimentos',
        label: 'Alimentos',
        icon: Icons.shopping_basket_rounded,
        query: 'alimentos',
      ),
      _SearchCategory(
        id: 'electronica',
        label: 'Electronica',
        icon: Icons.devices_rounded,
        query: 'electronica',
      ),
      _SearchCategory(
        id: 'ropa',
        label: 'Ropa',
        icon: Icons.checkroom_rounded,
        query: 'ropa',
      ),
      _SearchCategory(
        id: 'ferreteria',
        label: 'Ferreteria',
        icon: Icons.hardware_rounded,
        query: 'ferreteria',
      ),
    ],
  ),
  _SearchCategory(
    id: 'propiedades',
    label: 'Propiedades',
    icon: Icons.home_work_rounded,
    query: 'propiedad',
    children: [
      _SearchCategory(
        id: 'casa',
        label: 'Casas',
        icon: Icons.house_rounded,
        query: 'casa',
      ),
      _SearchCategory(
        id: 'apartamento',
        label: 'Apartamentos',
        icon: Icons.apartment_rounded,
        query: 'apartamento',
      ),
      _SearchCategory(
        id: 'alquiler',
        label: 'Alquileres',
        icon: Icons.key_rounded,
        query: 'alquiler',
      ),
      _SearchCategory(
        id: 'terreno',
        label: 'Terrenos',
        icon: Icons.terrain_rounded,
        query: 'terreno',
      ),
    ],
  ),
  _SearchCategory(
    id: 'gastronomia',
    label: 'Gastronomia',
    icon: Icons.restaurant_rounded,
    query: 'gastronomia',
    children: [
      _SearchCategory(
        id: 'restaurante',
        label: 'Restaurantes',
        icon: Icons.restaurant_menu_rounded,
        query: 'restaurante',
      ),
      _SearchCategory(
        id: 'bar',
        label: 'Bares',
        icon: Icons.local_bar_rounded,
        query: 'bar',
      ),
      _SearchCategory(
        id: 'discoteca',
        label: 'Discotecas',
        icon: Icons.nightlife_rounded,
        query: 'discoteca',
      ),
      _SearchCategory(
        id: 'cafeteria',
        label: 'Cafeterias',
        icon: Icons.local_cafe_rounded,
        query: 'cafeteria',
      ),
      _SearchCategory(
        id: 'pizzeria',
        label: 'Pizzerias',
        icon: Icons.local_pizza_rounded,
        query: 'pizzeria',
      ),
    ],
  ),
  _SearchCategory(
    id: 'vehiculos',
    label: 'Vehiculos',
    icon: Icons.directions_car_rounded,
    query: 'auto moto',
    children: [
      _SearchCategory(
        id: 'auto',
        label: 'Autos',
        icon: Icons.directions_car_rounded,
        query: 'auto',
      ),
      _SearchCategory(
        id: 'moto',
        label: 'Motos',
        icon: Icons.two_wheeler_rounded,
        query: 'moto',
      ),
      _SearchCategory(
        id: 'moto-electrica',
        label: 'Motos electricas',
        icon: Icons.electric_moped_rounded,
        query: 'moto electrica',
      ),
      _SearchCategory(
        id: 'triciclo',
        label: 'Triciclos',
        icon: Icons.pedal_bike_rounded,
        query: 'triciclo',
      ),
      _SearchCategory(
        id: 'camion',
        label: 'Camiones',
        icon: Icons.local_shipping_rounded,
        query: 'camion',
      ),
    ],
  ),
  _SearchCategory(
    id: 'transporte',
    label: 'Transporte',
    icon: Icons.local_shipping_rounded,
    query: 'transporte',
    children: [
      _SearchCategory(
        id: 'delivery',
        label: 'Delivery',
        icon: Icons.delivery_dining_rounded,
        query: 'delivery',
      ),
      _SearchCategory(
        id: 'taxi',
        label: 'Taxi',
        icon: Icons.local_taxi_rounded,
        query: 'taxi',
      ),
      _SearchCategory(
        id: 'carga',
        label: 'Carga',
        icon: Icons.local_shipping_rounded,
        query: 'carga',
      ),
      _SearchCategory(
        id: 'mudanza',
        label: 'Mudanzas',
        icon: Icons.move_up_rounded,
        query: 'mudanza',
      ),
    ],
  ),
];

class _AssetResultTile extends StatelessWidget {
  const _AssetResultTile(this.asset, {this.onTap});

  final SearchAssetModel asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final location = [
      asset.municipality,
      asset.province,
    ].where((value) => value != null && value.isNotEmpty).join(', ');
    final price = asset.price == null
        ? 'Consultar'
        : '${asset.price!.toStringAsFixed(0)} ${asset.currency ?? 'CUP'}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Row(
            children: [
              SizedBox(
                width: 118,
                height: double.infinity,
                child: asset.imageUrl?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: asset.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.place_outlined),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          Icons.place_outlined,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [asset.type, location, asset.description]
                            .where((value) => value != null && value.isNotEmpty)
                            .join(' - '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSectionTitle extends StatelessWidget {
  const _MiniSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: Icons.manage_search_rounded,
      title: 'Buscar en ConKkao',
      message: message,
      color: Theme.of(context).colorScheme.secondary,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 46, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
