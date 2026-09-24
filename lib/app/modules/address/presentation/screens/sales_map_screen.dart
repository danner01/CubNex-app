import 'dart:async';
import 'dart:convert';
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
  List<_ProvinciaVentas> _provincias = const [];
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
          _provincias = data.resumenPorProvincia;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _SummaryChip(
                      icon: Icons.storefront_rounded,
                      label: 'Negocios',
                      value: '${data.totalNegocios}',
                    ),
                    const SizedBox(width: 10),
                    _SummaryChip(
                      icon: Icons.inventory_2_rounded,
                      label: 'Productos',
                      value: '${data.totalProductos}',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${data.resumenPorProvincia.length} provincias',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 3,
                child: _buildMap(),
              ),
              Expanded(
                flex: 2,
                child: _buildList(data),
              ),
            ],
          );
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
        final provincia = _annotationMap[annotation.id];
        if (provincia != null && mounted) {
          unawaited(_flyTo(provincia));
        }
      },
    );
    await _syncAnnotations();
  }

  final Map<String, _ProvinciaVentas> _annotationMap = {};

  Future<void> _syncAnnotations() async {
    final pointManager = _pointManager;
    if (pointManager == null) return;
    final keys = _provincias.map(_annotationKey).toList();
    final same = keys.length == _renderedKeys.length &&
        keys.join('|') == _renderedKeys.join('|');
    if (same) return;
    _renderedKeys = keys;
    _annotationMap.clear();
    await pointManager.deleteAll();
    final annotations = <PointAnnotationOptions>[];
    for (final provincia in _provincias) {
      final imagenes = await _markerBytes(provincia);
      annotations.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(provincia.lng, provincia.lat),
          ),
          image: imagenes,
          iconSize: (1 + (provincia.cantidadProductos / 60).clamp(0, 1.4)),
        ),
      );
    }
    if (annotations.isNotEmpty) {
      final created = await pointManager.createMulti(annotations);
      for (var i = 0; i < created.length && i < _provincias.length; i += 1) {
        final annotation = created[i];
        if (annotation != null) {
          _annotationMap[annotation.id] = _provincias[i];
        }
      }
    }
  }

  String _annotationKey(_ProvinciaVentas provincia) {
    return 'pv_${provincia.provincia}_${provincia.lat}_${provincia.lng}';
  }

  Future<Uint8List> _markerBytes(_ProvinciaVentas provincia) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = ui.Size(96, 112);
    final fill = Paint()..color = AppColors.gold;
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

    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: '${provincia.cantidadProductos}',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, 31),
    );

    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _flyTo(_ProvinciaVentas provincia) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(provincia.lng, provincia.lat)),
        zoom: 8.2,
      ),
      MapAnimationOptions(duration: 750),
    );
  }

  Widget _buildList(_MapaVentas data) {
    final negocios = data.negocios;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: negocios.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            'Con mas productos en venta',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          );
        }
        final negocio = negocios[index - 1];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => context.go(AppRoutes.store(negocio.id)),
            leading: _AvatarNegocio(negocio: negocio),
            title: Text(
              negocio.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              [
                negocio.provincia,
                negocio.municipio,
                if (negocio.calificacionPromedio != null)
                  '${_fmtNumero(negocio.calificacionPromedio!, 1)} estrellas',
              ]
                  .where((part) => part != null && part.toString().isNotEmpty)
                  .join(' · '),
            ),
            trailing: Text(
              '${negocio.cantidadProductos} prods.',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.goldDark),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _AvatarNegocio extends StatelessWidget {
  const _AvatarNegocio({required this.negocio});

  final _NegocioVentas negocio;

  @override
  Widget build(BuildContext context) {
    final url = negocio.logoUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
        child: const Icon(Icons.storefront_rounded, color: AppColors.goldDark),
      );
    }
    final avatarBytes = _decodedLogo(url);
    return CircleAvatar(
      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
      foregroundImage: avatarBytes != null
          ? MemoryImage(avatarBytes)
          : NetworkImage(url),
      child: const Icon(Icons.storefront_rounded, color: AppColors.goldDark),
    );
  }

  Uint8List? _decodedLogo(String url) {
    if (!url.startsWith('data:image')) return null;
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } catch (_) {
      return null;
    }
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
  });

  final String id;
  final String nombre;
  final String? provincia;
  final String? municipio;
  final String? logoUrl;
  final double? calificacionPromedio;
  final int cantidadProductos;

  factory _NegocioVentas.fromJson(Map<String, dynamic> json) {
    return _NegocioVentas(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      provincia: json['provincia']?.toString(),
      municipio: json['municipio']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      calificacionPromedio: _doubleValue(json['calificacion_promedio']),
      cantidadProductos: _intValue(json['cantidad_productos']),
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

String _fmtNumero(double value, int decimals) {
  return value.toStringAsFixed(decimals).replaceAll('.', ',');
}