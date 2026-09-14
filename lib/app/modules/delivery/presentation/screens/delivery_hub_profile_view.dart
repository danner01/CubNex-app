import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
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
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Perfil delivery',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Vehiculo, tarifas, verificacion y disponibilidad.'),
              const SizedBox(height: 16),
              if (state.status == DeliveryStatus.loading && profile == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (profile == null) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.55,
                      ),
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
                ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Gestion'),
                const SizedBox(height: 4),
                ..._buildGestions(context, profile),
              ] else ...[
                _buildAvailabilityCard(context, state),
                const SizedBox(height: 12),
                DeliveryProfileSummaryCard(profile: profile),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Gestion'),
                const SizedBox(height: 4),
                ..._buildGestions(context, profile),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    );
  }

  List<Widget> _buildGestions(
    BuildContext context,
    DeliveryProfileModel? profile,
  ) {
    final items = [
      if (profile != null)
        _DeliveryProfileItem(
          title: 'Editar perfil',
          subtitle: 'Vehiculo, tarifa, radio y placa.',
          icon: Icons.edit_outlined,
          onTap: () => showDeliveryProfileEditSheet(context, profile),
        ),
      const _DeliveryProfileItem(
        title: 'Ruta y mapa',
        subtitle: 'Entregas activas y ubicacion en tiempo real.',
        icon: Icons.map_outlined,
        route: AppRoutes.deliveryRoute,
      ),
      const _DeliveryProfileItem(
        title: 'Solicitudes',
        subtitle: 'Ordenes disponibles para aceptar.',
        icon: Icons.assignment_outlined,
        route: AppRoutes.deliveryRequests,
      ),
      const _DeliveryProfileItem(
        title: 'Historial de entregas',
        subtitle: 'Ordenes completadas, kilometros y pagos.',
        icon: Icons.history_rounded,
        route: AppRoutes.deliveryHistory,
      ),
      const _DeliveryProfileItem(
        title: 'Panel delivery',
        subtitle: 'Solicitudes, entregas y estado operativo.',
        icon: Icons.space_dashboard_outlined,
        route: AppRoutes.deliveryDashboard,
      ),
      const _DeliveryProfileItem(
        title: 'Billetera',
        subtitle: 'Saldo ConKkao, transferencias y movimientos.',
        icon: Icons.account_balance_wallet_outlined,
        route: AppRoutes.credits,
      ),
    ];
    return items
        .map(
          (item) => _DeliveryProfileTile(
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            onTap: () {
              final route = item.route;
              if (route != null) {
                context.go(route);
              } else {
                item.onTap?.call();
              }
            },
          ),
        )
        .toList();
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

class _DeliveryProfileTile extends StatelessWidget {
  const _DeliveryProfileTile({
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
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

class _DeliveryProfileItem {
  const _DeliveryProfileItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  final VoidCallback? onTap;
}

class DeliveryProfileSummaryCard extends StatelessWidget {
  const DeliveryProfileSummaryCard({required this.profile, super.key});

  final DeliveryProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  backgroundColor: theme.colorScheme.secondary.withValues(
                    alpha: 0.16,
                  ),
                  child: Icon(
                    deliveryVehicleIcon(profile.vehicleType),
                    color: theme.colorScheme.secondary,
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
    ('auto', 'Auto'),
    ('camioneta', 'Camioneta'),
    ('camion', 'Camion'),
  ];

  late final TextEditingController _plateController;
  late final TextEditingController _baseRateController;
  late final TextEditingController _perKmController;
  late final TextEditingController _radiusController;
  late String _vehicleType;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.profile.vehicleType ?? 'motorina';
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
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
            const Text('Actualiza tu vehiculo, tarifas y radio de operacion.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
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
                onPressed: _saving ? null : () => unawaited(_save()),
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

  String _money(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }
}
