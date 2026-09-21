import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';

class DeliveryMetaChip extends StatelessWidget {
  const DeliveryMetaChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryStatusPill extends StatelessWidget {
  const DeliveryStatusPill({
    required this.status,
    required this.label,
    super.key,
  });

  final String? status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = switch (status) {
      'completado' || 'cerrado' => DeliveryStatusVisual(
        Colors.green,
        Icons.check_circle_rounded,
      ),
      'cancelado' => DeliveryStatusVisual(
        Theme.of(context).colorScheme.error,
        Icons.cancel_rounded,
      ),
      'en_ruta' || 'delivery_asignado' || 'recogido_por_delivery' =>
        DeliveryStatusVisual(Colors.blue, Icons.local_shipping_rounded),
      'entregado_por_delivery' || 'recibido_cliente' => DeliveryStatusVisual(
        Colors.teal,
        Icons.qr_code_scanner_rounded,
      ),
      _ => DeliveryStatusVisual(
        Theme.of(context).colorScheme.primary,
        Icons.receipt_long_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 14, color: visual.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: visual.color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryStatusVisual {
  const DeliveryStatusVisual(this.color, this.icon);

  final Color color;
  final IconData icon;
}

class DeliveryMessageCard extends StatelessWidget {
  const DeliveryMessageCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

String formatDeliveryDistance(double? km) {
  if (km == null) return '-';
  if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
  return '${km.toStringAsFixed(1)} km';
}

String formatDeliveryMoney(double? value, String currency) {
  if (value == null) return 'Consultar $currency';
  return '${value.toStringAsFixed(2)} $currency';
}

IconData deliveryVehicleIcon(String? vehiculo) {
  return switch (vehiculo) {
    'bicicleta' => Icons.pedal_bike,
    'motorina' => Icons.two_wheeler,
    'moto' => Icons.two_wheeler,
    'auto' => Icons.directions_car,
    'camioneta' => Icons.local_shipping,
    'camion' => Icons.local_fire_department,
    _ => Icons.delivery_dining,
  };
}

const deliveryMarkerPalette = [
  '#1E88E5',
  '#43A047',
  '#FB8C00',
  '#8E24AA',
  '#00897B',
  '#D81B60',
  '#6D4C41',
  '#3949AB',
];

const deliveryDefaultMarkerColor = '#1E88E5';

Color? parseDeliveryMarkerColor(Object? hex) {
  final raw = hex?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final normalized = raw.replaceFirst('#', '');
  final masked = normalized.length == 6
      ? 'FF$normalized'
      : normalized.length == 8
      ? normalized
      : normalized.padLeft(8, 'F');
  return Color(int.tryParse(masked, radix: 16) ?? 0xFF1E88E5);
}

Color readableDeliveryMarkerIconColor(Color background) {
  final luminance = background.computeLuminance();
  return luminance > 0.45 ? Colors.black : Colors.white;
}

class DeliveryActionData {
  const DeliveryActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class DeliveryActionsGrid extends StatelessWidget {
  const DeliveryActionsGrid({required this.actions, super.key});

  final List<DeliveryActionData> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action.icon,
                    size: 30,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DeliverySuggestionItem {
  const DeliverySuggestionItem({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

class DeliveryMapSearchOverlay extends StatefulWidget {
  const DeliveryMapSearchOverlay({
    required this.mapboxMap,
    this.onFocusLocation,
    this.label = 'Buscar direccion...',
    this.onUseCurrentLocation,
    super.key,
  });

  final MapboxMap mapboxMap;
  final void Function(double lat, double lng)? onFocusLocation;
  final String label;
  final Future<void> Function()? onUseCurrentLocation;

  @override
  State<DeliveryMapSearchOverlay> createState() =>
      _DeliveryMapSearchOverlayState();
}

class _DeliveryMapSearchOverlayState extends State<DeliveryMapSearchOverlay> {
  final ApiClient _apiClient = sl<ApiClient>();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _searching = false;
  bool _locating = false;
  List<DeliverySuggestionItem> _suggestions = const [];
  bool _showSuggestions = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = const [];
        _showSuggestions = false;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _showSuggestions = true;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_search(trimmed));
    });
  }

  Future<void> _search(String query) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      '/mapbox/geocodificar',
      queryParameters: {'direccion': '$query, Cuba'},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      if (result.isSuccess) {
        _suggestions = _parseSuggestions(result.data);
      } else {
        _suggestions = const [];
      }
    });
  }

  List<DeliverySuggestionItem> _parseSuggestions(Map<String, dynamic>? data) {
    final raw = data?['features'] ?? data?['resultados'] ?? data?['lugares'];
    if (raw is! List) return const [];
    final items = <DeliverySuggestionItem>[];
    for (final entry in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final label =
          map['place_name'] ??
          map['placeName'] ??
          map['direccion'] ??
          map['nombre'] ??
          map['text'];
      if (label is! String || label.trim().isEmpty) continue;

      double? lat;
      double? lng;
      final center = map['center'];
      if (center is List && center.length >= 2) {
        lng = _toDouble(center[0]);
        lat = _toDouble(center[1]);
      }
      final geometry = map['geometry'];
      if (geometry is Map && geometry['coordinates'] is List) {
        final coordinates = geometry['coordinates'] as List;
        if (coordinates.length >= 2) {
          lng = _toDouble(coordinates[0]);
          lat = _toDouble(coordinates[1]);
        }
      }
      if (lat == null || lng == null) continue;
      items.add(
        DeliverySuggestionItem(
          label: label.trim(),
          latitude: lat,
          longitude: lng,
        ),
      );
      if (items.length >= 5) break;
    }
    return items;
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _select(DeliverySuggestionItem suggestion) {
    _controller.text = suggestion.label;
    _focusNode.unfocus();
    setState(() {
      _suggestions = const [];
      _showSuggestions = false;
    });
    unawaited(
      widget.mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(suggestion.longitude, suggestion.latitude),
          ),
          zoom: 15,
        ),
        MapAnimationOptions(duration: 600),
      ),
    );
    widget.onFocusLocation?.call(suggestion.latitude, suggestion.longitude);
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    _focusNode.unfocus();
    try {
      if (widget.onUseCurrentLocation != null) {
        await widget.onUseCurrentLocation!();
        return;
      }
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
      unawaited(
        widget.mapboxMap.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(position.longitude, position.latitude),
            ),
            zoom: 15,
          ),
          MapAnimationOptions(duration: 600),
        ),
      );
      widget.onFocusLocation?.call(position.latitude, position.longitude);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _field(ThemeData theme) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onTap: () {
          if (_controller.text.trim().isEmpty) return;
          setState(() => _showSuggestions = true);
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.label,
          prefixIcon: _searching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search_rounded),
          prefixIconColor: theme.colorScheme.primary,
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 64,
          top: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(theme),
              if (_showSuggestions) ...[
                const SizedBox(height: 4),
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  color: theme.colorScheme.surface,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: _suggestions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _searching
                                  ? 'Buscando...'
                                  : 'Sin resultados. Escribe mas detalle.',
                              style: theme.textTheme.bodySmall,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.place_outlined,
                                  size: 20,
                                ),
                                title: Text(
                                  suggestion.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onTap: () => _select(suggestion),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'delivery_map_locate',
            onPressed: _locating ? null : () => unawaited(_useCurrentLocation()),
            tooltip: 'Mi ubicacion',
            child: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }
}
