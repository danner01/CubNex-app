import 'package:flutter/widgets.dart';

import 'web_map_unavailable.dart';
import 'web_mapbox_models.dart';

class WebTrackingMap extends StatelessWidget {
  const WebTrackingMap({
    required this.latitude,
    required this.longitude,
    this.markers = const [],
    this.routes = const [],
    this.onMapTap,
    this.onMarkerTap,
    super.key,
  });

  final double latitude;
  final double longitude;
  final List<WebMapMarker> markers;
  final List<WebMapRoute> routes;
  final ValueChanged<({double latitude, double longitude})>? onMapTap;
  final ValueChanged<String>? onMarkerTap;

  @override
  Widget build(BuildContext context) => const WebMapUnavailable();
}
