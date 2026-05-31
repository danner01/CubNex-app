import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/environment/app_environment.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/map/map_cubit.dart';
import '../../blocs/map/map_state.dart';
import '../../data/models/map_search_item.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MapCubit>()..load(),
      child: const _MapView(),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final _searchController = TextEditingController();
  MapboxMap? _mapboxMap;
  MapSearchItem? _selectedItem;
  late final bool _tokenReady;

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<MapCubit, MapState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
          _flyTo(state.latitude, state.longitude, zoom: 13.5);
        },
        builder: (context, state) {
          final visibleItems = state.visibleItems;

          return RefreshIndicator(
            onRefresh: () => context.read<MapCubit>().load(query: state.query),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Mapa',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Explora negocios, propiedades y servicios de transporte cerca de ti.',
                ),
                const SizedBox(height: 14),
                SearchBar(
                  controller: _searchController,
                  leading: const Icon(Icons.search_rounded),
                  hintText: 'Buscar en el mapa...',
                  trailing: [
                    IconButton(
                      tooltip: 'Buscar',
                      onPressed: () => context.read<MapCubit>().load(
                        query: _searchController.text,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                  onSubmitted: (value) =>
                      context.read<MapCubit>().load(query: value),
                ),
                const SizedBox(height: 14),
                _MapCanvas(
                  tokenReady: _tokenReady,
                  latitude: state.latitude,
                  longitude: state.longitude,
                  selectedItem: _selectedItem,
                  onMapCreated: (mapboxMap) => _mapboxMap = mapboxMap,
                  onLocate: state.locating
                      ? null
                      : () => context.read<MapCubit>().useCurrentLocation(),
                ),
                const SizedBox(height: 14),
                _FilterRow(
                  selectedType: state.selectedType,
                  onSelected: context.read<MapCubit>().filterByType,
                ),
                const SizedBox(height: 14),
                if (state.status == MapStatus.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visibleItems.isEmpty)
                  const _EmptyMapState()
                else ...[
                  Text(
                    '${visibleItems.length} resultados con ubicacion',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...visibleItems.map(
                    (item) => _MapResultCard(
                      item: item,
                      selected: _selectedItem?.id == item.id,
                      onTap: () => _selectItem(item),
                      onOpen: () => _openItem(context, item),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectItem(MapSearchItem item) async {
    setState(() => _selectedItem = item);
    context.read<MapCubit>().selectLocation(item.latitude, item.longitude);
    await _flyTo(item.latitude, item.longitude, zoom: 15);
  }

  Future<void> _flyTo(
    double latitude,
    double longitude, {
    double zoom = 14,
  }) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 650),
    );
  }

  void _openItem(BuildContext context, MapSearchItem item) {
    switch (item.type) {
      case MapSearchType.business:
        context.go(AppRoutes.store(item.id));
      case MapSearchType.property:
        context.go(AppRoutes.property(item.id));
      case MapSearchType.transport:
        context.go(AppRoutes.transportService(item.id));
    }
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.tokenReady,
    required this.latitude,
    required this.longitude,
    required this.selectedItem,
    required this.onMapCreated,
    required this.onLocate,
  });

  final bool tokenReady;
  final double latitude;
  final double longitude;
  final MapSearchItem? selectedItem;
  final ValueChanged<MapboxMap> onMapCreated;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 360,
        child: Stack(
          children: [
            Positioned.fill(
              child: tokenReady
                  ? MapWidget(
                      viewport: CameraViewportState(
                        center: Point(
                          coordinates: Position(longitude, latitude),
                        ),
                        zoom: 12.5,
                      ),
                      onMapCreated: onMapCreated,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 48,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Configura MAPBOX_ACCESS_TOKEN para activar el mapa interactivo.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  selectedItem == null
                      ? Icons.my_location_rounded
                      : Icons.location_pin,
                  key: ValueKey(selectedItem?.id ?? 'current'),
                  size: 44,
                  color: selectedItem == null
                      ? theme.colorScheme.secondary
                      : AppColors.danger,
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: FloatingActionButton.small(
                heroTag: 'map-location',
                onPressed: onLocate,
                child: onLocate == null
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
            if (selectedItem != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      selectedItem!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedType,
    required this.onSelected,
  });

  final MapSearchType? selectedType;
  final ValueChanged<MapSearchType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Todos',
            icon: Icons.public_rounded,
            selected: selectedType == null,
            onTap: () => onSelected(null),
          ),
          _FilterChip(
            label: 'Negocios',
            icon: Icons.storefront_rounded,
            selected: selectedType == MapSearchType.business,
            onTap: () => onSelected(MapSearchType.business),
          ),
          _FilterChip(
            label: 'Propiedades',
            icon: Icons.home_work_rounded,
            selected: selectedType == MapSearchType.property,
            onTap: () => onSelected(MapSearchType.property),
          ),
          _FilterChip(
            label: 'Transporte',
            icon: Icons.local_shipping_rounded,
            selected: selectedType == MapSearchType.transport,
            onTap: () => onSelected(MapSearchType.transport),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _MapResultCard extends StatelessWidget {
  const _MapResultCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final MapSearchItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      item.municipality,
      item.province,
      item.address,
    ].where((value) => value != null && value.isNotEmpty).join(' - ');
    final price = item.price == null
        ? null
        : '${item.price!.toStringAsFixed(0)} ${item.currency ?? 'CUP'}';

    return Card(
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                child: Icon(_iconForType(item.type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (price != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            price,
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [item.typeLabel, location, item.description]
                          .where((value) => value != null && value.isNotEmpty)
                          .join(' - '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onOpen != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Abrir',
                  onPressed: onOpen,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(MapSearchType type) {
    return switch (type) {
      MapSearchType.business => Icons.storefront_rounded,
      MapSearchType.property => Icons.home_work_rounded,
      MapSearchType.transport => Icons.local_shipping_rounded,
    };
  }
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 46,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            Text(
              'Sin ubicaciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aun no hay resultados con coordenadas para mostrar en el mapa.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
