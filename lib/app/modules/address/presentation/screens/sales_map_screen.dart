import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/environment/app_environment.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';

class SalesMapScreen extends StatefulWidget {
  const SalesMapScreen({super.key});

  @override
  State<SalesMapScreen> createState() => _SalesMapScreenState();
}

class _SalesMapScreenState extends State<SalesMapScreen> {
  late final bool _tokenReady;
  late Future<_MapaVentas?> _future;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  List<_NegocioVentas> _negocios = const [];
  List<String> _renderedKeys = const [];

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
    _future = _load();
  }

  Future<_MapaVentas?> _load() async {
    final result = await sl<ApiClient>().get<Map<String, dynamic>?>(
      '/productos/mapa-ventas',
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : null,
    );
    if (!result.isSuccess || result.data == null) return null;
    return _MapaVentas.fromJson(result.data!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de ventas de Cuba')),
      body: FutureBuilder<_MapaVentas?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No pudimos cargar el mapa de ventas.'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _future = _load()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          _negocios = data.negocios;
          return _buildMap();
        },
      ),
    );
  }

  Widget _buildMap() {
    if (!_tokenReady) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Configura MAPBOX_ACCESS_TOKEN para activar el mapa interactivo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }
    return MapWidget(
      // ignore: deprecated_member_use
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(-79.4, 21.6)),
        zoom: 5.4,
      ),
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.gestures.updateSettings(
      GesturesSettings(
        scrollEnabled: true,
        pinchToZoomEnabled: true,
        rotateEnabled: true,
        pitchEnabled: false,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
      ),
    );
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _pointManager?.setIconAllowOverlap(true);
    _pointManager?.tapEvents(
      onTap: (annotation) {
        final negocio = _annotationMap[annotation.id];
        if (negocio != null && mounted) {
          unawaited(_openNegocio(negocio));
        }
      },
    );
    await _syncAnnotations();
  }

  final Map<String, _NegocioVentas> _annotationMap = {};

  Future<void> _syncAnnotations() async {
    final pointManager = _pointManager;
    if (pointManager == null) return;
    final keys = _negocios.map(_annotationKey).toList();
    final same = keys.length == _renderedKeys.length &&
        keys.join('|') == _renderedKeys.join('|');
    if (same) return;
    _renderedKeys = keys;
    _annotationMap.clear();
    await pointManager.deleteAll();
    final annotations = <PointAnnotationOptions>[];
    for (final negocio in _negocios) {
      final lat = negocio.lat;
      final lng = negocio.lng;
      if (lat == null || lng == null) continue;
      annotations.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          image: await _markerBytes(negocio),
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: 1,
        ),
      );
    }
    if (annotations.isNotEmpty) {
      final created = await pointManager.createMulti(annotations);
      for (var i = 0; i < created.length; i += 1) {
        final annotation = created[i];
        if (annotation != null && i < annotations.length) {
          final match = _negocios
              .where((negocio) => negocio.lat != null && negocio.lng != null)
              .toList();
          if (i < match.length) {
            _annotationMap[annotation.id] = match[i];
          }
        }
      }
    }
  }

  String _annotationKey(_NegocioVentas negocio) {
    return 'nv_${negocio.id}_${negocio.lat}_${negocio.lng}';
  }

  Future<void> _openNegocio(_NegocioVentas negocio) async {
    if (!mounted) return;
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(negocio.lng ?? -79.4, negocio.lat ?? 21.6),
        ),
        zoom: 11,
      ),
      MapAnimationOptions(duration: 750),
    );
    if (mounted) context.go(AppRoutes.store(negocio.id));
  }

  Future<Uint8List> _markerBytes(_NegocioVentas negocio) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = ui.Size(48, 56);
    final color =
        _colorFromHex(negocio.themeColor) ?? AppColors.goldDark;
    final fill = Paint()..color = color;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path()
      ..addOval(const Rect.fromLTWH(6, 4, 36, 36))
      ..moveTo(24, 52)
      ..quadraticBezierTo(12, 36, 15, 26)
      ..quadraticBezierTo(24, 39, 33, 26)
      ..quadraticBezierTo(36, 36, 24, 52)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.2));
    canvas.drawPath(path.shift(const Offset(0, -2)), fill);
    canvas.drawPath(path.shift(const Offset(0, -2)), border);

    final icon = _iconFor(negocio.tipoIcon);
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, 12),
    );

    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
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

  IconData _iconFor(String? icon) {
    return switch (icon?.trim().toLowerCase()) {
      'truck' => Icons.local_shipping_outlined,
      'car' || 'car-front' => Icons.directions_car_outlined,
      'home' || 'building' => Icons.home_work_outlined,
      'utensils' || 'coffee' => Icons.restaurant_outlined,
      'scissors' => Icons.content_cut,
      'wrench' => Icons.handyman_outlined,
      'shirt' => Icons.checkroom_outlined,
      'smartphone' || 'monitor' => Icons.devices_outlined,
      'gas' || 'fuel' => Icons.local_gas_station_outlined,
      'book' || 'education' => Icons.menu_book_outlined,
      _ => Icons.storefront_outlined,
    };
  }
}

class _MapaVentas {
  const _MapaVentas({
    required this.totalNegocios,
    required this.totalProductos,
    required this.resumenPorProvincia,
    required this.negocios,
  });

  final int totalNegocios;
  final int totalProductos;
  final List<_ProvinciaVentas> resumenPorProvincia;
  final List<_NegocioVentas> negocios;

  factory _MapaVentas.fromJson(Map<String, dynamic> json) {
    final provincias = <_ProvinciaVentas>[];
    final rawProvincias = json['resumen_por_provincia'];
    if (rawProvincias is List) {
      for (final item in rawProvincias) {
        if (item is! Map) continue;
        provincias.add(_ProvinciaVentas.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final negocios = <_NegocioVentas>[];
    final rawNegocios = json['negocios'];
    if (rawNegocios is List) {
      for (final item in rawNegocios) {
        if (item is! Map) continue;
        negocios.add(_NegocioVentas.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final totalProductos = _intValue(json['total_productos']);
    final totalNegocios = _intValue(json['total_negocios']);

    return _MapaVentas(
      totalNegocios: totalNegocios == 0 && negocios.isNotEmpty
          ? negocios.length
          : totalNegocios,
      totalProductos: totalProductos == 0 && provincias.isNotEmpty
          ? provincias
                .fold<int>(
                  0,
                  (total, provincia) => total + provincia.cantidadProductos,
                )
          : totalProductos,
      resumenPorProvincia: provincias,
      negocios: negocios,
    );
  }
}

class _ProvinciaVentas {
  const _ProvinciaVentas({
    required this.provincia,
    required this.cantidadNegocios,
    required this.cantidadProductos,
    required this.lat,
    required this.lng,
  });

  final String provincia;
  final int cantidadNegocios;
  final int cantidadProductos;
  final double lat;
  final double lng;

  factory _ProvinciaVentas.fromJson(Map<String, dynamic> json) {
    return _ProvinciaVentas(
      provincia: json['provincia']?.toString() ?? 'Otros',
      cantidadNegocios: _intValue(json['cantidad_negocios']),
      cantidadProductos: _intValue(json['cantidad_productos']),
      lat: _doubleValue(json['lat']) ?? 21.6,
      lng: _doubleValue(json['lng']) ?? -79.4,
    );
  }
}

class _NegocioVentas {
  const _NegocioVentas({
    required this.id,
    required this.nombre,
    this.provincia,
    this.municipio,
    this.logoUrl,
    this.calificacionPromedio,
    required this.cantidadProductos,
    this.lat,
    this.lng,
    this.themeColor,
    this.tipoIcon,
  });

  final String id;
  final String nombre;
  final String? provincia;
  final String? municipio;
  final String? logoUrl;
  final double? calificacionPromedio;
  final int cantidadProductos;
  final double? lat;
  final double? lng;
  final String? themeColor;
  final String? tipoIcon;

  factory _NegocioVentas.fromJson(Map<String, dynamic> json) {
    final coloresRaw = json['colores'];
    String? themeColor;
    if (coloresRaw is Map) {
      themeColor = (coloresRaw['primario'] ??
              coloresRaw['primary'] ??
              coloresRaw['acento'])
          ?.toString();
    }
    final tipoRaw = json['tipo_negocio'];
    String? tipoIcon;
    if (tipoRaw is Map) {
      tipoIcon = tipoRaw['icono']?.toString();
    } else if (tipoRaw is String) {
      tipoIcon = tipoRaw;
    }

    return _NegocioVentas(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      provincia: json['provincia']?.toString(),
      municipio: json['municipio']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      calificacionPromedio: _doubleValue(json['calificacion_promedio']),
      cantidadProductos: _intValue(json['cantidad_productos']),
      lat: _doubleValue(json['lat']),
      lng: _doubleValue(json['lng']),
      themeColor: themeColor,
      tipoIcon: tipoIcon,
    );
  }
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double? _doubleValue(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}