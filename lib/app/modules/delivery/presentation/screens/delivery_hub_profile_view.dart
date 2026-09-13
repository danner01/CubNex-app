import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../../blocs/delivery/delivery_state.dart';
import '../../data/models/delivery_profile_model.dart';
import '../widgets/delivery_common.dart';

class DeliveryHubProfileView extends StatelessWidget {
  const DeliveryHubProfileView({super.key});

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
                const Text(
                  'Aun no tienes perfil delivery configurado. Desde el panel '
                  'de delivery puedes registrarte como repartidor para aceptar '
                  'entregas.',
                ),
              ] else ...[
                DeliveryProfileSummaryCard(profile: profile),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: state.isUpdatingProfile
                      ? null
                      : () => showDeliveryProfileEditSheet(context, profile),
                  icon: state.isUpdatingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.edit_outlined, size: 20),
                  label: Text(
                    state.isUpdatingProfile ? 'Guardando...' : 'Editar perfil',
                  ),
                ),
              ],
            ],
          );
        },
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
    final trustLevel = profile.trustLevel ?? 'nuevo';
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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DeliveryProfileEditSheet(profile: profile),
  );
}

class _DeliveryProfileEditSheet extends StatefulWidget {
  const _DeliveryProfileEditSheet({required this.profile});

  final DeliveryProfileModel profile;

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
    await context.read<DeliveryCubit>().updateProfile(
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
