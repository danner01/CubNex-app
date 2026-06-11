import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
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
  final _scrollController = ScrollController();
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _routeManager;
  MapSearchItem? _selectedItem;
  final Map<String, MapSearchItem> _annotationItems = {};
  late final bool _tokenReady;
  List<MapSearchItem> _lastRenderedItems = const [];
  List<MapRoutePoint> _lastRenderedRoute = const [];

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
          unawaited(_syncMapAnnotations(state));
        },
        builder: (context, state) {
          final visibleItems = state.visibleItems;

          return RefreshIndicator(
            onRefresh: () => context.read<MapCubit>().load(query: state.query),
            child: ListView(
              controller: _scrollController,
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
                  onMapCreated: (mapboxMap) async {
                    final cubit = context.read<MapCubit>();
                    _mapboxMap = mapboxMap;
                    await _setupMap(mapboxMap);
                    if (mounted) {
                      await _syncMapAnnotations(cubit.state);
                    }
                  },
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
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _MapResultCard(
                        item: item,
                        selected: _selectedItem?.id == item.id,
                        onTap: () => _selectItem(item),
                        onOpen: () => _openItem(context, item),
                      ),
                    ),
                  ),
                  if (state.loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
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
    await context.read<MapCubit>().selectItem(item);
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 360) return;
    context.read<MapCubit>().loadMore();
  }

  Future<void> _setupMap(MapboxMap mapboxMap) async {
    await mapboxMap.gestures.updateSettings(
      GesturesSettings(
        scrollEnabled: true,
        pinchToZoomEnabled: true,
        rotateEnabled: true,
        pitchEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
      ),
    );
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _routeManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _pointManager?.setIconAllowOverlap(true);
    _pointManager?.tapEvents(
      onTap: (annotation) {
        final item = _annotationItems[annotation.id];
        if (item != null && mounted) {
          unawaited(_selectItem(item));
        }
      },
    );
  }

  Future<void> _syncMapAnnotations(MapState state) async {
    final pointManager = _pointManager;
    final routeManager = _routeManager;
    if (pointManager == null || routeManager == null) return;
    final routeColor = Theme.of(context).colorScheme.primary.toARGB32();

    final items = state.visibleItems;
    final sameItems =
        _lastRenderedItems.length == items.length &&
        _lastRenderedItems.map((item) => item.id).join('|') ==
            items.map((item) => item.id).join('|');
    if (!sameItems) {
      _lastRenderedItems = List.of(items);
      _annotationItems.clear();
      await pointManager.deleteAll();
      final annotations = <PointAnnotationOptions>[];
      for (final item in items) {
        annotations.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(item.longitude, item.latitude),
            ),
            image: await _markerBytes(item),
            iconSize: 1,
          ),
        );
      }
      final created = await pointManager.createMulti(annotations);
      for (var i = 0; i < created.length && i < items.length; i += 1) {
        final annotation = created[i];
        if (annotation != null) _annotationItems[annotation.id] = items[i];
      }
    }

    final route = state.routePoints;
    final sameRoute =
        _lastRenderedRoute.length == route.length &&
        _lastRenderedRoute
                .map((point) => '${point.latitude},${point.longitude}')
                .join('|') ==
            route
                .map((point) => '${point.latitude},${point.longitude}')
                .join('|');
    if (sameRoute) return;
    _lastRenderedRoute = List.of(route);
    await routeManager.deleteAll();
    if (route.length < 2) return;

    await routeManager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: route
              .map((point) => Position(point.longitude, point.latitude))
              .toList(),
        ),
        lineColor: routeColor,
        lineBorderColor: Colors.white.toARGB32(),
        lineBorderWidth: 1.4,
        lineWidth: 5.5,
        lineOpacity: 0.92,
      ),
    );
  }

  Future<Uint8List> _markerBytes(MapSearchItem item) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = ui.Size(96, 112);
    final color = _colorFromHex(item.themeColor) ?? _colorForType(item.type);
    final fill = Paint()..color = color;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final path = Path()
      ..addOval(const Rect.fromLTWH(10, 6, 76, 76))
      ..moveTo(48, 108)
      ..quadraticBezierTo(22, 72, 28, 52)
      ..quadraticBezierTo(48, 78, 68, 52)
      ..quadraticBezierTo(74, 72, 48, 108)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.2));
    canvas.drawPath(path.shift(const Offset(0, -3)), fill);
    canvas.drawPath(path.shift(const Offset(0, -3)), border);

    final icon = _iconForType(item.type);
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 38,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, 23));

    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Color? _colorFromHex(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll('#', '');
    final parsed = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return parsed == null ? null : Color(parsed);
  }

  Color _colorForType(MapSearchType type) {
    return switch (type) {
      MapSearchType.business => AppColors.gold,
      MapSearchType.property => AppColors.green,
      MapSearchType.transport => AppColors.blue,
    };
  }

  IconData _iconForType(MapSearchType type) {
    return switch (type) {
      MapSearchType.business => Icons.storefront_rounded,
      MapSearchType.property => Icons.home_work_rounded,
      MapSearchType.transport => Icons.local_shipping_rounded,
    };
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
                      // ignore: deprecated_member_use
                      cameraOptions: CameraOptions(
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.route_rounded,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedItem!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
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
  const _FilterRow({required this.selectedType, required this.onSelected});

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
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 118,
                  height: 104,
                  child: item.imageUrl == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: _colorForType(
                              item.type,
                            ).withValues(alpha: 0.18),
                          ),
                          child: Icon(
                            _iconForType(item.type),
                            color: _colorForType(item.type),
                            size: 34,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => DecoratedBox(
                            decoration: BoxDecoration(
                              color: _colorForType(
                                item.type,
                              ).withValues(alpha: 0.18),
                            ),
                            child: Icon(
                              _iconForType(item.type),
                              color: _colorForType(item.type),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 104,
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
                            Flexible(
                              child: Text(
                                price,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w900,
                                ),
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
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _TinyStatus(
                            icon: _iconForType(item.type),
                            label: item.typeLabel,
                            color: _colorForType(item.type),
                          ),
                          if (item.type == MapSearchType.business)
                            _TinyStatus(
                              icon: item.availableNow
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_filled_rounded,
                              label: item.availableNow ? 'Activo' : 'Pausado',
                              color: item.availableNow
                                  ? AppColors.greenLight
                                  : Colors.redAccent,
                            ),
                          if (item.requiresElectricity)
                            _TinyStatus(
                              icon: Icons.bolt_rounded,
                              label: item.hasElectricService
                                  ? 'Con corriente'
                                  : 'Sin corriente',
                              color: item.hasElectricService
                                  ? AppColors.greenLight
                                  : AppColors.goldDark,
                            ),
                        ],
                      ),
                    ],
                  ),
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

  Color _colorForType(MapSearchType type) {
    return switch (type) {
      MapSearchType.business => AppColors.gold,
      MapSearchType.property => AppColors.green,
      MapSearchType.transport => AppColors.blue,
    };
  }
}

class _TinyStatus extends StatelessWidget {
  const _TinyStatus({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
