import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../blocs/favorites/favorites_cubit.dart';
import '../../blocs/favorites/favorites_state.dart';
import '../../data/models/favorite_model.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FavoritesCubit>()..load(),
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatefulWidget {
  const _FavoritesView();

  @override
  State<_FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<_FavoritesView> {
  String _filter = 'todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<FavoritesCubit, FavoritesState>(
        listener: (context, state) {
          final message = state.message ?? state.errorMessage;
          if (message != null && message.isNotEmpty) {
            showSnackOrAuthDialog(context, message);
          }
        },
        builder: (context, state) {
          if (state.status == FavoritesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => context.read<FavoritesCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Favoritos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Productos, negocios y servicios guardados.'),
                const SizedBox(height: 18),
                if (state.items.isNotEmpty) ...[
                  _FavoriteFilters(
                    selected: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 14),
                ],
                if (state.status == FavoritesStatus.failure)
                  _MessageCard(
                    icon: Icons.error_outline_rounded,
                    message: state.errorMessage ?? 'No se pudo cargar.',
                  )
                else if (state.items.isEmpty)
                  const _MessageCard(
                    icon: Icons.favorite_border_rounded,
                    message: 'Todavia no tienes favoritos guardados.',
                  )
                else
                  ...state.items.where(_matchesFilter).map(
                    (favorite) => _FavoriteTile(
                      favorite,
                      onDelete: () => context
                          .read<FavoritesCubit>()
                          .deleteFavorite(favorite.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilter(FavoriteModel favorite) {
    return _filter == 'todos' || favorite.entityType == _filter;
  }
}

class _FavoriteFilters extends StatelessWidget {
  const _FavoriteFilters({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('todos', 'Todos'),
      ('negocio', 'Negocios'),
      ('producto', 'Productos'),
      ('servicio', 'Delivery/servicios'),
      ('propiedad', 'Propiedades'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options
            .map(
              (option) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(option.$2),
                  selected: selected == option.$1,
                  onSelected: (_) => onChanged(option.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile(this.favorite, {required this.onDelete});

  final FavoriteModel favorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(favorite.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _openFavorite(context),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 104,
                child: favorite.imageUrl?.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: favorite.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _FallbackFavoriteIcon(favorite.entityType),
                      )
                    : _FallbackFavoriteIcon(favorite.entityType),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.title?.isNotEmpty == true
                            ? favorite.title!
                            : favorite.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        favorite.subtitle?.isNotEmpty == true
                            ? '${favorite.label} - ${favorite.subtitle}'
                            : favorite.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFavorite(BuildContext context) {
    switch (favorite.entityType) {
      case 'producto':
        context.go(AppRoutes.product(favorite.entityId));
      case 'negocio':
        context.go(AppRoutes.store(favorite.entityId));
      case 'propiedad':
        context.go(AppRoutes.property(favorite.entityId));
      case 'servicio':
        context.go(AppRoutes.transportService(favorite.entityId));
      default:
        return;
    }
  }

}

class _FallbackFavoriteIcon extends StatelessWidget {
  const _FallbackFavoriteIcon(this.type);

  final String type;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        _iconFor(type),
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'producto' => Icons.inventory_2_outlined,
      'negocio' => Icons.storefront_outlined,
      'propiedad' => Icons.home_work_outlined,
      'servicio' => Icons.handyman_outlined,
      _ => Icons.favorite_border_rounded,
    };
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              icon,
              size: 46,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
