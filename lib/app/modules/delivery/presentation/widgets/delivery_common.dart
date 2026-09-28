import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../../blocs/delivery/delivery_state.dart';

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

class DeliveryRouteColors {
  const DeliveryRouteColors._();

  static const origin = Color(0xFF2E7D32);
  static const destination = Color(0xFFC62828);
  static const route = Color(0xFF1E88E5);
  static const manualRoute = Color(0xFF6A1B9A);
  static const delivery = Color(0xFF3949AB);
}

class DeliverySheetPanel extends StatelessWidget {
  const DeliverySheetPanel({
    required this.controller,
    required this.child,
    super.key,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class DeliveryMapLegendRow extends StatelessWidget {
  const DeliveryMapLegendRow({
    required this.myColor,
    required this.showAcceptRoute,
    required this.showManualRoute,
    super.key,
  });

  final Color myColor;
  final bool showAcceptRoute;
  final bool showManualRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[
      _legendItem(
        theme,
        myColor,
        'Tu',
        labelColor: readableDeliveryMarkerIconColor(myColor),
      ),
      _legendItem(theme, DeliveryRouteColors.delivery, 'Repartidor'),
      if (showAcceptRoute) ...[
        _legendItem(theme, DeliveryRouteColors.origin, 'Origen'),
        _legendItem(theme, DeliveryRouteColors.destination, 'Destino'),
        _legendItem(theme, DeliveryRouteColors.route, 'Ruta', line: true),
      ],
      if (showManualRoute)
        _legendItem(
          theme,
          DeliveryRouteColors.manualRoute,
          'Ruta manual',
          line: true,
        ),
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  items[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(
    ThemeData theme,
    Color color,
    String label, {
    Color? labelColor,
    bool line = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (line)
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
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

/// Motivo por el que no se pudo leer la ubicacion, para poder explicar el fallo
/// en vez de tragarselo en silencio.
enum DeliveryLocationStatus {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  error,
}

class DeliveryLocationResult {
  const DeliveryLocationResult({
    required this.status,
    this.position,
    this.fromLastKnown = false,
  });

  const DeliveryLocationResult.ok(
    geo.Position position, {
    bool fromLastKnown = false,
  }) : this(
         status: DeliveryLocationStatus.ok,
         position: position,
         fromLastKnown: fromLastKnown,
       );

  final DeliveryLocationStatus status;
  final geo.Position? position;

  /// `true` cuando se uso la ultima posicion conocida porque el GPS no respondio a tiempo.
  final bool fromLastKnown;

  bool get hasPosition => position != null;

  String get message => switch (status) {
    DeliveryLocationStatus.ok =>
      fromLastKnown
          ? 'Usando tu ultima posicion conocida. Sal a un lugar abierto para actualizarla.'
          : '',
    DeliveryLocationStatus.serviceDisabled =>
      'La ubicacion del dispositivo esta apagada. Activala e intenta de nuevo.',
    DeliveryLocationStatus.permissionDenied =>
      'Permiso de ubicacion denegado. Concedelo desde los ajustes e intenta de nuevo.',
    DeliveryLocationStatus.permissionDeniedForever =>
      'El permiso de ubicacion esta bloqueado. Habilitalo desde los ajustes de la app.',
    DeliveryLocationStatus.timeout =>
      'El GPS no respondio a tiempo. Sal a un lugar abierto e intenta de nuevo.',
    DeliveryLocationStatus.error =>
      'No se pudo leer tu ubicacion. Revisa los permisos e intenta de nuevo.',
  };
}

/// Lectura de ubicacion unificada para todo el modulo delivery.
///
/// `getCurrentPosition()` a secas se queda esperando indefinido en varios Android y
/// lanza `TimeoutException`, lo que dejaba el mapa de la cola sin ubicacion. Aqui se
/// pone un limite de tiempo y se cae a la ultima posicion conocida.
Future<DeliveryLocationResult> readDeliveryPosition({
  Duration timeLimit = const Duration(seconds: 12),
  bool requestPermission = true,
}) async {
  try {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return const DeliveryLocationResult(
        status: DeliveryLocationStatus.serviceDisabled,
      );
    }
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied && requestPermission) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.deniedForever) {
      return const DeliveryLocationResult(
        status: DeliveryLocationStatus.permissionDeniedForever,
      );
    }
    if (permission == geo.LocationPermission.denied) {
      return const DeliveryLocationResult(
        status: DeliveryLocationStatus.permissionDenied,
      );
    }

    // IMPORTANTE: en Android el `timeLimit` del LocationSettings se ignora y
    // getCurrentPosition puede quedarse esperando el primer fix sin devolver
    // nada; por eso se envuelve siempre en `Future.timeout`. Si nadie lo
    // corta, la pantalla se queda para siempre en "Detectar mi posicion".
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      ).timeout(timeLimit);
      return DeliveryLocationResult.ok(position);
    } catch (error) {
      debugPrint('DeliveryLocation: GPS alta sin fix en $timeLimit ($error)');
    }

    // Intento 2: precision media (suele encajar mas rapido usando red/celda).
    const mediumLimit = Duration(seconds: 8);
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: mediumLimit,
        ),
      ).timeout(mediumLimit);
      return DeliveryLocationResult.ok(position);
    } catch (error) {
      debugPrint('DeliveryLocation: GPS media sin fix ($error)');
    }

    try {
      final last = await geo.Geolocator.getLastKnownPosition();
      if (last != null) {
        return DeliveryLocationResult.ok(last, fromLastKnown: true);
      }
    } catch (_) {}
    return const DeliveryLocationResult(status: DeliveryLocationStatus.timeout);
  } catch (error) {
    debugPrint('DeliveryLocation: fallo leyendo la ubicacion: $error');
    return const DeliveryLocationResult(status: DeliveryLocationStatus.error);
  }
}

/// Pide la ruta por carretera entre dos puntos usando el backend.
Future<List<List<double>>> fetchDeliveryStreetRoute({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
}) async {
  final result = await sl<ApiClient>().post<Map<String, dynamic>>(
    '/mapbox/ruta',
    data: {
      'origen': {'lat': originLat, 'lng': originLng},
      'destino': {'lat': destLat, 'lng': destLng},
    },
    parser: (json) => json is Map ? Map<String, dynamic>.from(json) : const {},
  );
  if (!result.isSuccess) return const [];

  final routes = result.data?['routes'];
  if (routes is! List || routes.isEmpty) return const [];
  final first = routes.first;
  if (first is! Map) return const [];
  final geometry = first['geometry'];
  if (geometry is! Map) return const [];
  final coords = geometry['coordinates'];
  if (coords is! List) return const [];

  final parsed = <List<double>>[];
  for (final entry in coords) {
    if (entry is List && entry.length >= 2) {
      final lng = (entry[0] as num?)?.toDouble();
      final lat = (entry[1] as num?)?.toDouble();
      if (lng != null && lat != null && lng.isFinite && lat.isFinite) {
        parsed.add([lng, lat]);
      }
    }
  }
  return parsed;
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

const int _deliveryMarkerIconSize = 72;
const double _deliveryMarkerIconScale = 2;

final Map<String, String> _deliveryMarkerIconCache = {};

final Map<String, String> _deliveryPinIconCache = {};

String _deliveryMarkerIconKey(Color color, String? vehicle) {
  final vehicleKey = (vehicle ?? 'delivery').trim().toLowerCase();
  final colorKey = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return 'del_marker_${vehicleKey}_$colorKey';
}

/// Genera y registra en el estilo del mapa un icono de repartidor con el
/// color configurado en su perfil y el glifo del vehiculo. Devuelve el id
/// del icono para usarlo en `iconImage`, o null si no pudo registrarlo.
Future<String?> ensureDeliveryMarkerIcon(
  MapboxMap map,
  Color color,
  String? vehicle,
) async {
  final key = _deliveryMarkerIconKey(color, vehicle);
  final cached = _deliveryMarkerIconCache[key];
  if (cached != null) {
    await _tryRestoreStyleImage(map, key);
    return key;
  }

  final png = await _buildDeliveryMarkerPng(color, vehicle);
  if (png == null) return null;
  _deliveryMarkerIconPngCache[key] = png;

  try {
    await map.style.addStyleImage(
      key,
      1.0,
      MbxImage(
        width: _deliveryMarkerIconSize,
        height: _deliveryMarkerIconSize,
        data: png,
      ),
      false,
      const [],
      const [],
      null,
    );
  } catch (_) {
    return null;
  }
  _deliveryMarkerIconCache[key] = key;
  return key;
}

/// Registra en el estilo del mapa un pin (gota) del color indicado y con un
/// texto opcional en su centro (origen/destino/numero de parada). Devuelve el
/// id del icono para usarlo en `iconImage`, o null si no pudo registrarlo.
Future<String?> ensureDeliveryPinIcon(
  MapboxMap map,
  Color color, {
  String? label,
  String keyPrefix = 'del_pin',
}) async {
  final safeLabel = label?.trim().replaceAll(RegExp(r'\s+'), '_');
  final key =
      '${keyPrefix}_${color.toARGB32().toRadixString(16).padLeft(8, '0')}_${safeLabel?.toLowerCase() ?? 'n'}';
  final cached = _deliveryPinIconCache[key];
  if (cached != null) {
    await _tryRestorePinStyleImage(map, key);
    return key;
  }

  final png = await _buildDeliveryPinPng(color, safeLabel);
  if (png == null) return null;
  _deliveryPinIconPngCache[key] = png;

  try {
    await map.style.addStyleImage(
      key,
      1.0,
      MbxImage(data: png, width: 64, height: 64),
      false,
      const [],
      const [],
      null,
    );
  } catch (_) {
    return null;
  }
  _deliveryPinIconCache[key] = key;
  return key;
}

/// Re-registra el icono por si el estilo del mapa se recargo (por ejemplo al
/// reconstruirse el mapa) y la imagen quedo fuera de el.
Future<void> _tryRestoreStyleImage(MapboxMap map, String key) async {
  final png = _deliveryMarkerIconPngCache[key];
  if (png == null) return;
  try {
    await map.style.addStyleImage(
      key,
      1.0,
      MbxImage(
        width: _deliveryMarkerIconSize,
        height: _deliveryMarkerIconSize,
        data: png,
      ),
      false,
      const [],
      const [],
      null,
    );
  } catch (_) {
    // La imagen ya existe en el estilo: sin problema.
  }
}

Future<void> _tryRestorePinStyleImage(MapboxMap map, String key) async {
  final png = _deliveryPinIconPngCache[key];
  if (png == null) return;
  try {
    await map.style.addStyleImage(
      key,
      1.0,
      MbxImage(data: png, width: 64, height: 64),
      false,
      const [],
      const [],
      null,
    );
  } catch (_) {
    // La imagen ya existe en el estilo: sin problema.
  }
}

final Map<String, Uint8List> _deliveryMarkerIconPngCache = {};
final Map<String, Uint8List> _deliveryPinIconPngCache = {};

Future<Uint8List?> _buildDeliveryMarkerPng(Color color, String? vehicle) async {
  final scale = _deliveryMarkerIconScale;
  final size = _deliveryMarkerIconSize.toDouble();
  final hiSize = (_deliveryMarkerIconSize * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  final center = size / 2;
  final radius = size * 0.42;

  canvas.drawCircle(
    Offset(center, center),
    radius + 5,
    Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
  canvas.drawCircle(Offset(center, center), radius, Paint()..color = color);
  canvas.drawCircle(
    Offset(center, center),
    radius,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );

  final icon = deliveryVehicleIcon(vehicle);
  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily ?? 'MaterialIcons',
        package: icon.fontPackage,
        fontSize: size * 0.46,
        color: readableDeliveryMarkerIconColor(color),
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  textPainter.paint(
    canvas,
    Offset(center - textPainter.width / 2, center - textPainter.height / 2),
  );

  final big = await recorder.endRecording().toImage(hiSize, hiSize);
  final downRecorder = ui.PictureRecorder();
  final downCanvas = Canvas(downRecorder)..scale(1 / scale);
  downCanvas.drawImage(
    big,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.high,
  );
  final small = await downRecorder.endRecording().toImage(
    _deliveryMarkerIconSize,
    _deliveryMarkerIconSize,
  );
  big.dispose();
  // IMPORTANTE: Android espera bytes PNG/JPEG (BitmapFactory.decodeByteArray),
  // no RGBA crudo. Si se envia RGBA, el icono no se registra en el estilo.
  final byteData = await small.toByteData(format: ui.ImageByteFormat.png);
  small.dispose();
  if (byteData == null) return null;
  return byteData.buffer.asUint8List();
}

const int _deliveryPinSize = 64;

Future<Uint8List?> _buildDeliveryPinPng(Color color, String? label) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = _deliveryPinSize.toDouble();

  final path = Path()
    ..moveTo(size / 2, size * 0.06)
    ..quadraticBezierTo(size * 0.16, size * 0.06, size * 0.16, size * 0.36)
    ..quadraticBezierTo(size * 0.16, size * 0.62, size / 2, size * 0.94)
    ..quadraticBezierTo(size * 0.84, size * 0.62, size * 0.84, size * 0.36)
    ..quadraticBezierTo(size * 0.84, size * 0.06, size / 2, size * 0.06)
    ..close();

  canvas.drawPath(
    path,
    Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawCircle(
    Offset(size / 2, size * 0.33),
    size * 0.19,
    Paint()..color = Colors.white,
  );

  final safeLabel = label;
  if (safeLabel != null && safeLabel.isNotEmpty) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: safeLabel,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: safeLabel.length > 2 ? size * 0.16 : size * 0.22,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF212121),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size * 0.33 - textPainter.height / 2,
      ),
    );
  }

  final image = await recorder.endRecording().toImage(
    _deliveryPinSize,
    _deliveryPinSize,
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) return null;
  return byteData.buffer.asUint8List();
}

/// Garantiza que el [DeliveryCubit] singleton cargue su estado al entrar a
/// una pantalla que lo consume. Debe usarse como hijo de un
/// [BlocProvider.value] para que NUNCA se cierre el cubit compartido.
class DeliveryCubitBootstrap extends StatefulWidget {
  const DeliveryCubitBootstrap({required this.child, super.key});

  final Widget child;

  @override
  State<DeliveryCubitBootstrap> createState() => _DeliveryCubitBootstrapState();
}

class _DeliveryCubitBootstrapState extends State<DeliveryCubitBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    final cubit = context.read<DeliveryCubit>();
    final status = cubit.state.status;
    if (status == DeliveryStatus.initial || status == DeliveryStatus.failure) {
      unawaited(cubit.load());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    this.showLocateFab = true,
    super.key,
  });

  final MapboxMap mapboxMap;
  final void Function(double lat, double lng)? onFocusLocation;
  final String label;
  final Future<void> Function()? onUseCurrentLocation;
  final bool showLocateFab;

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
      final result = await readDeliveryPosition();
      if (!result.hasPosition) {
        _showMessage(result.message);
        return;
      }
      final position = result.position!;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
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
        if (widget.showLocateFab)
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'delivery_map_locate',
              onPressed: _locating
                  ? null
                  : () => unawaited(_useCurrentLocation()),
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
