import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/presentation/widgets/apk_version_card.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../../blocs/delivery/delivery_state.dart';
import '../../data/models/delivery_profile_model.dart';
import '../widgets/delivery_common.dart';

class DeliveryHubProfileView extends StatelessWidget {
  const DeliveryHubProfileView({super.key});

  Future<void> _toggleAvailable(BuildContext context, bool value) async {
    if (!value) {
      unawaited(context.read<DeliveryCubit>().setDisponible(false));
      return;
    }
    final position = await _currentPosition(context);
    if (position == null || !context.mounted) return;
    unawaited(
      context.read<DeliveryCubit>().setDisponible(
        true,
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }

  Future<geo.Position?> _currentPosition(BuildContext context) async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!context.mounted) return null;
    if (!enabled) {
      showSnackOrAuthDialog(context, 'Activa la ubicacion del dispositivo.');
      return null;
    }
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (!context.mounted) return null;
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      showSnackOrAuthDialog(context, 'Permiso de ubicacion denegado.');
      return null;
    }
    return geo.Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<DeliveryCubit, DeliveryState>(
        listener: (context, state) {
          final error = state.errorMessage;
          if (error != null && error.isNotEmpty) {
            showSnackOrAuthDialog(context, error);
          }
        },
        builder: (context, state) {
          final profile = state.profile;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Perfil delivery',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Vehiculo, tarifas, avatar, color del marcador y disponibilidad.'),
              const SizedBox(height: 16),
              if (state.status == DeliveryStatus.loading && profile == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (profile == null) ...[
                const _DeliveryEmptyProfileCard(),
                const SizedBox(height: 18),
                _buildManagementLists(context, profile),
              ] else ...[
                _buildAvailabilityCard(context, state),
                const SizedBox(height: 12),
                DeliveryProfileSummaryCard(profile: profile),
                const SizedBox(height: 18),
                _buildManagementLists(context, profile),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildManagementLists(
    BuildContext context,
    DeliveryProfileModel? profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Operacion delivery'),
        _ProfileTile(
          icon: Icons.space_dashboard_outlined,
          title: 'Panel delivery',
          subtitle: 'Solicitudes, entregas activas, ingresos y reputacion.',
          onTap: () => context.go(AppRoutes.deliveryDashboard),
        ),
        _ProfileTile(
          icon: Icons.receipt_long_outlined,
          title: 'Solicitudes',
          subtitle: 'Ordenes disponibles para aceptar.',
          onTap: () => context.go(AppRoutes.deliveryRequests),
        ),
        _ProfileTile(
          icon: Icons.map_outlined,
          title: 'Ruta y mapa',
          subtitle: 'Entregas activas y ruta hacia el cliente.',
          onTap: () => context.go(AppRoutes.deliveryRoute),
        ),
        _ProfileTile(
          icon: Icons.history_rounded,
          title: 'Historial de entregas',
          subtitle: 'Ordenes completadas, kilometros y pagos.',
          onTap: () => context.go(AppRoutes.deliveryHistory),
        ),
        _ProfileTile(
          icon: Icons.near_me_outlined,
          title: 'Repartidores cerca',
          subtitle: 'Repartidores activos cercanos con su ubicacion en el mapa.',
          onTap: () => context.go(AppRoutes.deliveryNearby),
        ),
        const SizedBox(height: 10),
        _SectionLabel('Cuenta'),
        if (profile != null)
          _ProfileTile(
            icon: Icons.edit_outlined,
            title: 'Editar perfil',
            subtitle: 'Vehiculo, tarifas, avatar y color del marcador.',
            onTap: () => showDeliveryProfileEditSheet(context, profile),
          ),
        _ProfileTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Billetera',
          subtitle: 'Saldo ConKkao, transferencias por alias/QR y movimientos.',
          onTap: () => context.go(AppRoutes.credits),
        ),
        _ProfileTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notificaciones',
          subtitle: 'Avisos, solicitudes y mensajes del sistema.',
          onTap: () => context.go(AppRoutes.notifications),
        ),
        const SizedBox(height: 10),
        const _SectionLabel('Aplicacion'),
        _ProfileTile(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Privacidad y permisos',
          subtitle: 'Notificaciones, camara, ubicacion y ajustes de la app.',
          onTap: () => context.go(AppRoutes.preferences),
        ),
        const ApkVersionCard(),
        const SizedBox(height: 10),
        _SectionLabel('Sesion'),
        OutlinedButton.icon(
          onPressed: () async {
            await context.read<AppSessionCubit>().logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesion'),
        ),
      ],
    );
  }

  Widget _buildAvailabilityCard(BuildContext context, DeliveryState state) {
    final theme = Theme.of(context);
    final profile = state.profile!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: profile.available,
          onChanged: state.isUpdatingProfile
              ? null
              : (value) => unawaited(_toggleAvailable(context, value)),
          title: const Text('Disponible para entregas'),
          subtitle: Text(
            profile.active
                ? 'Los clientes y negocios podran solicitarte servicio.'
                : 'Tu perfil esta inactivo.',
          ),
          secondary: state.isUpdatingProfile
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Icon(
                  profile.available
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 28,
                  color: profile.available
                      ? Colors.green
                      : theme.colorScheme.outline,
                ),
        ),
      ),
    );
  }
}

class _DeliveryEmptyProfileCard extends StatelessWidget {
  const _DeliveryEmptyProfileCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.delivery_dining_outlined, size: 30),
            const SizedBox(height: 8),
            Text(
              'Aun no tienes perfil delivery',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Desde el panel de delivery puedes registrarte como '
              'repartidor para aceptar entregas.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class DeliveryProfileSummaryCard extends StatelessWidget {
  const DeliveryProfileSummaryCard({required this.profile, super.key});

  final DeliveryProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markerColor =
        parseDeliveryMarkerColor(profile.colorMarcador) ??
        parseDeliveryMarkerColor(deliveryDefaultMarkerColor) ??
        Colors.blue;
    final trustLevel = profile.trustLevel?.isNotEmpty == true
        ? profile.trustLevel!
        : 'nuevo';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: markerColor.withValues(alpha: 0.9),
                  foregroundColor: readableDeliveryMarkerIconColor(markerColor),
                  backgroundImage: profile.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl?.isNotEmpty == true
                      ? null
                      : Icon(
                          deliveryVehicleIcon(profile.vehicleType),
                          size: 28,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    profile.vehicleType ?? 'Sin vehiculo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                DeliveryStatusPill(
                  label: profile.available ? 'Disponible' : 'Offline',
                  status: profile.available ? 'completado' : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DeliveryMetaChip(
              icon: Icons.payments_outlined,
              label:
                  'Base ${_money(profile.baseRate)} + '
                  '${_money(profile.perKmRate)}/km',
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DeliveryMetaChip(
                  icon: Icons.local_shipping_outlined,
                  label: profile.vehicleType ?? 'Sin vehiculo',
                ),
                if (profile.plate != null && profile.plate!.isNotEmpty)
                  DeliveryMetaChip(
                    icon: Icons.badge_outlined,
                    label: 'Placa: ${profile.plate}',
                  ),
                DeliveryMetaChip(
                  icon: Icons.speed_rounded,
                  label:
                      'Radio ${profile.operatingRadiusKm.toStringAsFixed(0)} km',
                ),
                if (profile.averageRating != null)
                  DeliveryMetaChip(
                    icon: Icons.star_rounded,
                    label: profile.averageRating!.toStringAsFixed(1),
                  ),
                DeliveryMetaChip(
                  icon: Icons.verified_outlined,
                  label: profile.active ? 'Perfil activo' : 'Perfil inactivo',
                ),
                DeliveryMetaChip(
                  icon: Icons.workspace_premium_outlined,
                  label:
                      'Confianza: ${trustLevel[0].toUpperCase()}${trustLevel.substring(1)}',
                ),
                DeliveryMetaChip(
                  icon: Icons.inventory_2_outlined,
                  label: '${profile.completedDeliveries} entregas',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: markerColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '#${_hexColor(markerColor)}',
                        style: TextStyle(
                          color: markerColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String _hexColor(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }
}

Future<void> showDeliveryProfileEditSheet(
  BuildContext context,
  DeliveryProfileModel profile,
) {
  final cubit = context.read<DeliveryCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DeliveryProfileEditSheet(profile: profile, cubit: cubit),
  );
}

class _DeliveryProfileEditSheet extends StatefulWidget {
  const _DeliveryProfileEditSheet({required this.profile, required this.cubit});

  final DeliveryProfileModel profile;
  final DeliveryCubit cubit;

  @override
  State<_DeliveryProfileEditSheet> createState() =>
      _DeliveryProfileEditSheetState();
}

class _DeliveryProfileEditSheetState extends State<_DeliveryProfileEditSheet> {
  static const _vehicleOptions = [
    ('bicicleta', 'Bicicleta'),
    ('motorina', 'Motorina'),
    ('moto', 'Moto'),
    ('triciclo', 'Triciclo'),
    ('auto', 'Auto'),
    ('camioneta', 'Camioneta'),
    ('camion', 'Camion'),
  ];

  late final TextEditingController _plateController;
  late final TextEditingController _baseRateController;
  late final TextEditingController _perKmController;
  late final TextEditingController _radiusController;
  late String _vehicleType;
  late String? _colorMarcador;
  String? _avatarUrl;
  bool _uploadingAvatar = false;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.profile.vehicleType ?? 'motorina';
    _colorMarcador =
        widget.profile.colorMarcador ?? deliveryDefaultMarkerColor;
    _avatarUrl = widget.profile.avatarUrl;
    _plateController = TextEditingController(text: widget.profile.plate ?? '');
    _baseRateController = TextEditingController(
      text: _money(widget.profile.baseRate),
    );
    _perKmController = TextEditingController(
      text: _money(widget.profile.perKmRate),
    );
    _radiusController = TextEditingController(
      text: _money(widget.profile.operatingRadiusKm),
    );
  }

  @override
  void dispose() {
    _plateController.dispose();
    _baseRateController.dispose();
    _perKmController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baseRate = double.tryParse(_baseRateController.text.trim());
    final perKmRate = double.tryParse(_perKmController.text.trim());
    final radius = double.tryParse(_radiusController.text.trim());
    if (baseRate == null ||
        baseRate < 0 ||
        perKmRate == null ||
        perKmRate < 0 ||
        radius == null ||
        radius <= 0 ||
        radius > 500) {
      setState(() {
        _errorText = 'Revisa tarifa base, tarifa por km (>=0) y radio (0-500).';
      });
      return;
    }
    setState(() {
      _errorText = null;
      _saving = true;
    });
    await widget.cubit.updateProfile(
      vehicleType: _vehicleType,
      plate: _plateController.text,
      baseRate: baseRate,
      perKmRate: perKmRate,
      operatingRadiusKm: radius,
      avatarUrl: _avatarUrl,
      colorMarcador: _colorMarcador,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickAvatar() async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 900,
    );
    if (image == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    final url = await _uploadAvatar(image);
    if (!mounted) return;
    setState(() {
      _uploadingAvatar = false;
      if (url != null) _avatarUrl = url;
    });
    if (url == null) {
      showSnackOrAuthDialog(
        context,
        'No se pudo subir la imagen. Revisa conexion y permisos.',
      );
    }
  }

  Future<String?> _uploadAvatar(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final result = await sl<ApiClient>().post<Map<String, dynamic>>(
        '/storage/subir',
        data: {
          'archivo_base64': base64Encode(bytes),
          'nombre_archivo':
              'avatar-delivery-${DateTime.now().millisecondsSinceEpoch}.jpg',
          'content_type': image.mimeType ?? 'image/jpeg',
          'bucket': 'perfiles',
          'scope': 'avatar-delivery',
        },
        parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
      );
      final url = result.data?['public_url']?.toString();
      if (result.isSuccess && url != null && url.isNotEmpty) return url;
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escoger desde galeria'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final markerColor =
        parseDeliveryMarkerColor(_colorMarcador) ??
        parseDeliveryMarkerColor(deliveryDefaultMarkerColor) ??
        Colors.blue;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Editar perfil delivery',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Avatar, color del marcador, vehiculo, tarifas y radio de operacion.',
            ),
            const SizedBox(height: 16),
            _buildAvatarEditor(context, markerColor),
            const SizedBox(height: 16),
            _buildColorPicker(context, markerColor),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _vehicleOptions.any(
                (option) => option.$1 == _vehicleType,
              )
                  ? _vehicleType
                  : 'motorina',
              decoration: const InputDecoration(
                labelText: 'Vehiculo',
                border: OutlineInputBorder(),
              ),
              items: _vehicleOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.$1,
                      child: Text(option.$2),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _vehicleType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa',
                hintText: 'Opcional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseRateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tarifa base',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _perKmController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tarifa por km',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Radio de operacion (km)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _uploadingAvatar
                    ? null
                    : () => unawaited(_save()),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarEditor(BuildContext context, Color markerColor) {
    final theme = Theme.of(context);
    final hasAvatar = _avatarUrl?.isNotEmpty == true;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foto de perfil',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Se muestra a clientes y negocios junto a tu marcador en el mapa.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: hasAvatar
                          ? theme.colorScheme.surfaceContainerHighest
                          : markerColor.withValues(alpha: 0.9),
                      foregroundColor: hasAvatar
                          ? null
                          : readableDeliveryMarkerIconColor(markerColor),
                      backgroundImage: hasAvatar
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: hasAvatar
                          ? null
                          : Icon(
                              deliveryVehicleIcon(_vehicleType),
                              size: 32,
                            ),
                    ),
                    if (_uploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasAvatar)
                        Text(
                          'Imagen cargada.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _uploadingAvatar ? null : () => unawaited(_pickAvatar()),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(
                          hasAvatar ? 'Cambiar foto' : 'Subir foto',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(BuildContext context, Color markerColor) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Color del marcador en el mapa',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige el color con el que apareces en el mapa para clientes y negocios.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${_hexColor(markerColor)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: deliveryMarkerPalette.map((hex) {
                final color = parseDeliveryMarkerColor(hex) ?? Colors.blue;
                final selected = _colorMarcador?.toUpperCase() ==
                    hex.toUpperCase();
                return InkWell(
                  onTap: () => setState(() => _colorMarcador = hex),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: selected ? 38 : 34,
                    height: selected ? 38 : 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: selected ? 3 : 1,
                        color: selected
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.outlineVariant,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.secondary.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: readableDeliveryMarkerIconColor(color),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String _hexColor(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }
}