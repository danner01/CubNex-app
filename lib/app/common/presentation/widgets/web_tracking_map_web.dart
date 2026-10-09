import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../../config/environment/app_environment.dart';
import 'web_mapbox_models.dart';

class WebTrackingMap extends StatefulWidget {
  const WebTrackingMap({
    required this.latitude,
    required this.longitude,
    this.markers = const [],
    this.routes = const [],
    this.onMapTap,
    this.onMarkerTap,
    this.interactive = true,
    super.key,
  });

  final double latitude;
  final double longitude;
  final List<WebMapMarker> markers;
  final List<WebMapRoute> routes;
  final ValueChanged<({double latitude, double longitude})>? onMapTap;
  final ValueChanged<String>? onMarkerTap;
  final bool interactive;

  @override
  State<WebTrackingMap> createState() => _WebTrackingMapState();
}

class _WebTrackingMapState extends State<WebTrackingMap> {
  static var _nextViewId = 0;
  late final String _viewType;
  late final String _mapId;
  late final web.HTMLIFrameElement _iframe;
  late String _document;
  StreamSubscription<html.MessageEvent>? _messages;

  @override
  void initState() {
    super.initState();
    _viewType = 'delivery-tracking-map-${_nextViewId++}';
    _mapId = _viewType;
    _document = _mapDocument(widget.latitude, widget.longitude);
    _iframe = web.HTMLIFrameElement()
      ..srcdoc = _document.toJS
      ..style.border = '0'
      ..style.height = '100%'
      ..style.width = '100%'
      ..style.pointerEvents = widget.interactive ? 'auto' : 'none'
      ..title = 'Mapa de Mapbox';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _iframe);
    _messages = html.window.onMessage.listen(_handleMessage);
  }

  @override
  void didUpdateWidget(covariant WebTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final document = _mapDocument(widget.latitude, widget.longitude);
    if (document != _document) {
      _document = document;
      _iframe.srcdoc = document.toJS;
    }
    if (oldWidget.interactive != widget.interactive) {
      _iframe.style.pointerEvents = widget.interactive ? 'auto' : 'none';
    }
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);

  void _handleMessage(html.MessageEvent event) {
    final data = event.data;
    if (data is! String) return;
    final decoded = jsonDecode(data);
    if (decoded is! Map || decoded['mapId'] != _mapId) return;
    if (decoded['event'] == 'tap') {
      final latitude = decoded['latitude'];
      final longitude = decoded['longitude'];
      if (latitude is num && longitude is num) {
        widget.onMapTap?.call(
          (latitude: latitude.toDouble(), longitude: longitude.toDouble()),
        );
      }
    } else if (decoded['event'] == 'marker') {
      final id = decoded['id'];
      if (id is String) widget.onMarkerTap?.call(id);
    }
  }

  String _mapDocument(double latitude, double longitude) {
    final token = AppEnvironment.mapboxAccessToken;
    final configuration = jsonEncode({
      'mapId': _mapId,
      'center': [longitude, latitude],
      'markers': [
        for (final marker in widget.markers)
          {
            'id': marker.id,
            'coordinates': [marker.longitude, marker.latitude],
            'color': marker.color,
          },
      ],
      'routes': [
        for (final route in widget.routes)
          {
            'id': route.id,
            'coordinates': route.coordinates,
            'color': route.color,
            'width': route.width,
          },
      ],
    }).replaceAll('</', r'<\/');
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no">
  <link href="https://api.mapbox.com/mapbox-gl-js/v3.12.0/mapbox-gl.css" rel="stylesheet">
  <style>
    html, body, #map { margin: 0; height: 100%; width: 100%; }
    .mapboxgl-ctrl-group { box-shadow: 0 1px 4px rgba(0, 0, 0, .3); }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://api.mapbox.com/mapbox-gl-js/v3.12.0/mapbox-gl.js"></script>
  <script>
    mapboxgl.accessToken = '$token';
    const config = $configuration;
    const center = config.center;
    const map = new mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/streets-v12',
      center,
      zoom: 13,
      attributionControl: true,
    });
    map.addControl(new mapboxgl.NavigationControl(), 'top-right');
    map.addControl(new mapboxgl.GeolocateControl({
      positionOptions: { enableHighAccuracy: true },
      trackUserLocation: true,
      showUserHeading: true,
    }), 'top-right');
    map.on('load', () => {
      for (const route of config.routes) {
        const sourceId = 'route-' + route.id;
        map.addSource(sourceId, {
          type: 'geojson',
          data: { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: route.coordinates } },
        });
        map.addLayer({
          id: sourceId,
          type: 'line',
          source: sourceId,
          paint: { 'line-color': route.color, 'line-width': route.width, 'line-opacity': 0.88 },
        });
      }
      const markers = config.markers.length
        ? config.markers
        : [{ id: 'center', coordinates: center, color: '#D32F2F' }];
      for (const marker of markers) {
        const pin = new mapboxgl.Marker({ color: marker.color })
          .setLngLat(marker.coordinates)
          .addTo(map);
        pin.getElement().addEventListener('click', (event) => {
          event.stopPropagation();
          window.parent.postMessage(JSON.stringify({ mapId: config.mapId, event: 'marker', id: marker.id }), '*');
        });
      }
    });
    map.on('click', (event) => {
      window.parent.postMessage(JSON.stringify({
        mapId: config.mapId,
        event: 'tap',
        latitude: event.lngLat.lat,
        longitude: event.lngLat.lng,
      }), '*');
    });
  </script>
</body>
</html>
''';
  }
}
