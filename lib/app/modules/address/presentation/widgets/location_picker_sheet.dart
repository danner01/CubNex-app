import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/environment/app_environment.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';

class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;
}

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    this.initialLatitude,
    this.initialLongitude,
    this.title = 'Ubicacion',
    this.description = 'Toca el mapa para fijar el punto exacto o usa la ubicacion actual.',
    super.key,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String title;
  final String description;

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  static const _defaultLatitude = 23.1136;
  static const _defaultLongitude = -82.3666;

  MapboxMap? _mapboxMap;
  late final CameraViewportState _cameraViewport;
  late double _latitude = widget.initialLatitude ?? _defaultLatitude;
  late double _longitude = widget.initialLongitude ?? _defaultLongitude;
  late final bool _tokenReady;
  bool _resolvingAddress = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    _cameraViewport = CameraViewportState(
      center: Point(coordinates: Position(_longitude, _latitude)),
      zoom: 13,
    );
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(widget.description),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 360,
                child: _tokenReady
                    ? Stack(
                        children: [
                          MapWidget(
                            viewport: _cameraViewport,
                            onMapCreated: (mapboxMap) {
                              _mapboxMap = mapboxMap;
                              mapboxMap.addInteraction(
                                TapInteraction.onMap((gesture) async {
                                  final coordinates =
                                      gesture.point.coordinates;
                                  setState(() {
                                    _longitude = coordinates.lng.toDouble();
                                    _latitude = coordinates.lat.toDouble();
                                  });
                                  final cameraState =
                                      await mapboxMap.getCameraState();
                                  mapboxMap.flyTo(
                                    CameraOptions(
                                      center: Point(
                                        coordinates: Position(
                                          _longitude,
                                          _latitude,
                                        ),
                                      ),
                                      zoom: cameraState.zoom,
                                      pitch: cameraState.pitch,
                                      bearing: cameraState.bearing,
                                    ),
                                    MapAnimationOptions(duration: 140),
                                  );
                                }),
                                interactionID: 'location_picker_tap',
                              );
                            },
                          ),
                          Center(
                            child: Icon(
                              Icons.location_pin,
                              color: theme.colorScheme.error,
                              size: 42,
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Column(
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'location_picker_zoom_in',
                                  onPressed: () => _adjustZoom(0.9),
                                  child: const Icon(Icons.add),
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'location_picker_zoom_out',
                                  onPressed: () => _adjustZoom(-0.9),
                                  child: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 44,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Configura MAPBOX_ACCESS_TOKEN para mostrar el mapa.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Coordenadas: ${_latitude.toStringAsFixed(6)}, ${_longitude.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Tip: usa dos dedos para acercar/alejar y toca el mapa para marcar.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_locating || _resolvingAddress)
                        ? null
                        : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Mi ubicacion'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_locating || _resolvingAddress)
                        ? null
                        : _confirmSelection,
                    icon: _resolvingAddress
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _resolvingAddress ? 'Resolviendo direccion...' : 'Usar punto',
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage('Activa la ubicacion del dispositivo.');
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _showMessage('Permiso de ubicacion denegado.');
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_longitude, _latitude)),
          zoom: 15,
        ),
        MapAnimationOptions(duration: 650),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirmSelection() async {
    setState(() => _resolvingAddress = true);
    final address = await _resolveAddress();
    if (!mounted) return;
    setState(() => _resolvingAddress = false);
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _latitude,
        longitude: _longitude,
        address: address,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _adjustZoom(double delta) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    final cameraState = await mapboxMap.getCameraState();
    final nextZoom = (cameraState.zoom + delta).clamp(3.0, 19.0);
    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(_longitude, _latitude)),
        zoom: nextZoom,
      ),
      MapAnimationOptions(duration: 220),
    );
  }

  Future<String?> _resolveAddress() async {
    final result = await sl<ApiClient>().get<Map<String, dynamic>>(
      '/mapbox/geocodificar-inverso',
      queryParameters: {'lat': _latitude, 'lng': _longitude},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
    );
    if (!result.isSuccess || result.data == null) return null;
    final data = result.data!;
    final raw =
        data['direccion'] ??
        data['place_name'] ??
        data['placeName'] ??
        data['nombre'] ??
        data['address'];
    if (raw is! String) return null;
    final normalized = raw.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
