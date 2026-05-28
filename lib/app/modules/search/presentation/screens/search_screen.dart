import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          return ListView(
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
              const SectionHeader(title: 'Buscar por tipo'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  CategoryChipCard(
                    label: 'Productos',
                    icon: Icons.inventory_2_rounded,
                    onTap: () => _searchPreset(context, 'productos'),
                  ),
                  CategoryChipCard(
                    label: 'Servicios',
                    icon: Icons.handyman_rounded,
                    onTap: () => _searchPreset(context, 'servicios'),
                  ),
                  CategoryChipCard(
                    label: 'Negocios',
                    icon: Icons.storefront_rounded,
                    onTap: () => _searchPreset(context, 'negocios'),
                  ),
                  CategoryChipCard(
                    label: 'Propiedades',
                    icon: Icons.home_work_rounded,
                    onTap: () => context.go(AppRoutes.properties),
                  ),
                  CategoryChipCard(
                    label: 'Transporte',
                    icon: Icons.local_shipping_rounded,
                    onTap: () => context.go(AppRoutes.transport),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              QuickActionCard(
                title: 'Vista de mapa',
                subtitle: 'Negocios y anuncios con ubicacion.',
                icon: Icons.map_rounded,
                onTap: () => context.go(AppRoutes.map),
              ),
              const SizedBox(height: 12),
              QuickActionCard(
                title: 'Escaneo inteligente',
                subtitle: 'Busca por QR, codigo de barra o foto de etiqueta.',
                icon: Icons.camera_alt_rounded,
                onTap: () => context.go(AppRoutes.scanner),
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
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == SearchStatus.initial) {
      return const _EmptySearchState(
        message: 'Escribe una busqueda para encontrar negocios, productos y servicios.',
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
            height: 178,
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
                  rating: business.rating,
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
          ...state.results.properties.map(_AssetResultTile.new),
          const SizedBox(height: 18),
        ],
        if (state.results.transport.isNotEmpty) ...[
          const _MiniSectionTitle('Transporte'),
          const SizedBox(height: 10),
          ...state.results.transport.map(_AssetResultTile.new),
        ],
      ],
    );
  }
}

class _AssetResultTile extends StatelessWidget {
  const _AssetResultTile(this.asset);

  final SearchAssetModel asset;

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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          child: const Icon(Icons.place_outlined),
        ),
        title: Text(asset.title),
        subtitle: Text(
          [asset.type, location, asset.description]
              .where((value) => value != null && value.isNotEmpty)
              .join(' - '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          price,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w900,
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
      title: 'Buscar en CubNex',
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
