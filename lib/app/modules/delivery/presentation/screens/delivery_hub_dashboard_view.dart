import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../../blocs/delivery/delivery_state.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../widgets/delivery_common.dart';

class DeliveryHubDashboardView extends StatefulWidget {
  const DeliveryHubDashboardView({super.key});

  @override
  State<DeliveryHubDashboardView> createState() =>
      _DeliveryHubDashboardViewState();
}

class _DeliveryHubDashboardViewState extends State<DeliveryHubDashboardView> {
  static const _queueRefreshInterval = Duration(seconds: 12);
  static const _gpsReportInterval = Duration(seconds: 10);
  Timer? _queueTimer;
  Timer? _gpsTimer;
  bool _reportingLocation = false;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _queueTimer = Timer.periodic(_queueRefreshInterval, (_) {
      final cubit = context.read<DeliveryCubit>();
      if (cubit.state.profile?.available == true) {
        cubit.loadDisponibles(silent: true);
      }
    });
    _gpsTimer = Timer.periodic(_gpsReportInterval, (_) {
      unawaited(_reportCurrentGps());
    });
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _reportCurrentGps() async {
    final cubit = context.read<DeliveryCubit>();
    if (cubit.state.profile?.available != true) return;
    if (_reportingLocation) return;
    _reportingLocation = true;
    try {
      final position = await _currentPosition(silent: true);
      if (position != null && mounted) {
        await cubit.reportLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } finally {
      _reportingLocation = false;
    }
  }

  Future<void> _onToggle(bool value) async {
    if (value) {
      final position = await _currentPosition();
      if (position == null || !mounted) return;
      unawaited(
        context.read<DeliveryCubit>().setDisponible(
          true,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      return;
    }
    if (!mounted) return;
    unawaited(context.read<DeliveryCubit>().setDisponible(false));
  }

  Future<geo.Position?> _currentPosition({bool silent = false}) async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!silent) {
        _showMessage('Activa la ubicacion del dispositivo para ver entregas.');
      }
      return null;
    }
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (!silent) _showMessage('Permiso de ubicacion denegado.');
      return null;
    }
    return geo.Geolocator.getCurrentPosition();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showSnackOrAuthDialog(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<DeliveryCubit, DeliveryState>(
        listener: (context, state) {
          final error = state.queueError ?? state.errorMessage;
          if (error != null && error != _lastShownError) {
            _lastShownError = error;
            showSnackOrAuthDialog(context, error);
          }
          final accepted = state.acceptedEntrega;
          if (accepted != null) {
            context.read<DeliveryCubit>().clearAcceptedEntrega();
            unawaited(_showAcceptedDialog(accepted));
          }
        },
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Panel delivery',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Solicitudes, entregas y estado operativo.'),
              const SizedBox(height: 16),
              _buildAvailabilityCard(context, state),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Cola de entregas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (state.refreshingQueue)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  else
                    IconButton(
                      onPressed: () =>
                          context.read<DeliveryCubit>().loadDisponibles(),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar',
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ..._buildQueue(context, state),
              const SizedBox(height: 18),
              Text(
                'Gestion',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              DeliveryActionsGrid(
                actions: [
                  DeliveryActionData(
                    icon: Icons.receipt_long_outlined,
                    label: 'Solicitudes',
                    onTap: () => context.go(AppRoutes.deliveryRequests),
                  ),
                  DeliveryActionData(
                    icon: Icons.map_outlined,
                    label: 'Ruta y mapa',
                    onTap: () => context.go(AppRoutes.deliveryRoute),
                  ),
                  DeliveryActionData(
                    icon: Icons.history_rounded,
                    label: 'Historial',
                    onTap: () => context.go(AppRoutes.deliveryHistory),
                  ),
                  DeliveryActionData(
                    icon: Icons.badge_outlined,
                    label: 'Perfil delivery',
                    onTap: () => context.go(AppRoutes.deliveryProfile),
                  ),
                  DeliveryActionData(
                    icon: Icons.near_me_outlined,
                    label: 'Repartidores cerca',
                    onTap: () => context.go(AppRoutes.deliveryNearby),
                  ),
                  DeliveryActionData(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Billetera',
                    onTap: () => context.go(AppRoutes.credits),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvailabilityCard(BuildContext context, DeliveryState state) {
    final theme = Theme.of(context);
    final profile = state.profile;
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
                Icon(Icons.radar_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Disponibilidad',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (profile == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No tienes perfil delivery configurado. Registrate como '
                  'repartidor para aceptar entregas.',
                ),
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: profile.available,
                onChanged: state.isUpdatingProfile
                    ? null
                    : (value) => unawaited(_onToggle(value)),
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
                        size: 30,
                        color: profile.available
                            ? Colors.green
                            : theme.colorScheme.outline,
                      ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  DeliveryMetaChip(
                    icon: Icons.local_shipping_outlined,
                    label: profile.vehicleType ?? 'Sin vehiculo',
                  ),
                  DeliveryMetaChip(
                    icon: Icons.speed_rounded,
                    label:
                        'Tarifa ${profile.baseRate.toStringAsFixed(0)} + ${profile.perKmRate.toStringAsFixed(0)}/km',
                  ),
                  DeliveryMetaChip(
                    icon: Icons.radar_rounded,
                    label:
                        'Radio ${profile.operatingRadiusKm.toStringAsFixed(0)} km',
                  ),
                  DeliveryMetaChip(
                    icon: Icons.star_outline_rounded,
                    label: profile.averageRating == null
                        ? 'Sin calificar'
                        : profile.averageRating!.toStringAsFixed(1),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQueue(BuildContext context, DeliveryState state) {
    final profile = state.profile;
    if (profile == null) return const [];
    if (!profile.available) {
      return const [
        DeliveryMessageCard(
          message: 'Activa tu disponibilidad para ver la cola de entregas.',
        ),
      ];
    }
    final items = state.availableEntregas;
    if (state.status == DeliveryStatus.loading && items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 56),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (items.isEmpty) {
      return const [
        DeliveryMessageCard(message: 'No hay entregas disponibles por ahora.'),
      ];
    }
    return items
        .map(
          (entrega) => AvailableDeliveryCard(
            entrega: entrega,
            accepting: state.acceptingEntregaId == entrega.id,
            onAccept: () => unawaited(_confirmAccept(entrega)),
          ),
        )
        .toList();
  }

  Future<void> _confirmAccept(DeliveryEntregaModel entrega) async {
    final currency = entrega.moneda ?? 'CUP';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aceptar entrega'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Negocio',
                style: Theme.of(
                  dialogContext,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(entrega.negocioNombre ?? '-'),
              Text(entrega.negocioDireccion ?? ''),
              const SizedBox(height: 10),
              Text(
                'Cliente',
                style: Theme.of(
                  dialogContext,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(entrega.clienteNombre ?? '-'),
              Text(entrega.clienteDireccionEntrega ?? ''),
              const SizedBox(height: 10),
              Text(
                'Distancia estimada: ${formatDeliveryDistance(entrega.distanciaTotalKm)}',
              ),
              Text(
                'Tarifa estimada: ${formatDeliveryMoney(entrega.tarifaEstimada, currency)}',
              ),
              if (entrega.requiereRetornoDinero) ...[
                const SizedBox(height: 10),
                const Text(
                  'Incluye cobro y retorno de dinero al negocio.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Aceptar entrega'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<DeliveryCubit>().aceptar(entrega.id);
    }
  }

  Future<void> _showAcceptedDialog(DeliveryEntregaModel entrega) async {
    final currency = entrega.moneda ?? 'CUP';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
        title: const Text('Entrega aceptada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Negocio: ${entrega.negocioNombre ?? '-'}'),
            Text('Cliente: ${entrega.clienteNombre ?? '-'}'),
            const SizedBox(height: 6),
            Text(
              'Distancia: ${formatDeliveryDistance(entrega.distanciaTotalKm)}',
            ),
            Text(
              'Tarifa estimada: ${formatDeliveryMoney(entrega.tarifaEstimada, currency)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) context.go(AppRoutes.deliveryRoute);
            },
            child: const Text('Ver ruta'),
          ),
        ],
      ),
    );
  }
}

class AvailableDeliveryCard extends StatelessWidget {
  const AvailableDeliveryCard({
    required this.entrega,
    required this.accepting,
    required this.onAccept,
    super.key,
  });

  final DeliveryEntregaModel entrega;
  final bool accepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = entrega.moneda ?? 'CUP';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                  radius: 18,
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  child: const Icon(Icons.storefront_rounded, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entrega.negocioNombre ?? 'Entrega',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                DeliveryStatusPill(
                  status: 'reservado_delivery',
                  label: 'Solicitado',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _routeLine(
              Icons.arrow_downward_rounded,
              entrega.negocioDireccion ?? 'Sin direccion del negocio',
            ),
            _routeLine(
              Icons.location_on_outlined,
              entrega.clienteDireccionEntrega ??
                  (entrega.clienteNombre ?? 'Sin direccion de entrega'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DeliveryMetaChip(
                  icon: Icons.payments_outlined,
                  label: formatDeliveryMoney(entrega.tarifaEstimada, currency),
                ),
                DeliveryMetaChip(
                  icon: Icons.straighten_rounded,
                  label: formatDeliveryDistance(entrega.distanciaTotalKm),
                ),
                DeliveryMetaChip(
                  icon: Icons.near_me_rounded,
                  label:
                      'A ${formatDeliveryDistance(entrega.distanciaAlOrigenKm)}',
                ),
                DeliveryMetaChip(
                  icon: Icons.person_outline_rounded,
                  label: entrega.clienteNombre ?? 'Sin cliente',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: accepting ? null : onAccept,
                icon: accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.handshake_outlined),
                label: Text(accepting ? 'Aceptando...' : 'Aceptar entrega'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
