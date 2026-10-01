import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../../blocs/delivery/delivery_state.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../widgets/delivery_common.dart';
import 'delivery_hub_dashboard_view.dart';

class DeliverySolicitudesView extends StatefulWidget {
  const DeliverySolicitudesView({super.key});

  @override
  State<DeliverySolicitudesView> createState() => _DeliverySolicitudesViewState();
}

class _DeliverySolicitudesViewState extends State<DeliverySolicitudesView> {
  static const _queueRefreshInterval = Duration(seconds: 12);
  Timer? _queueTimer;
  String? _lastShownError;
  bool _autoOpenRouteAfterAccept = false;

  @override
  void initState() {
    super.initState();
    _queueTimer = Timer.periodic(_queueRefreshInterval, (_) {
      final cubit = context.read<DeliveryCubit>();
      if (cubit.state.profile?.available == true) {
        cubit.loadDisponibles(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
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
            if (_autoOpenRouteAfterAccept) {
              _autoOpenRouteAfterAccept = false;
              if (mounted) context.go(AppRoutes.deliveryRoute);
            } else {
              unawaited(_showAcceptedDialog(accepted));
            }
          }
        },
        builder: (context, state) {
          final profile = state.profile;
          final items = state.availableEntregas;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Solicitudes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pedidos pendientes por aceptar o rechazar.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Solicitudes de reparto',
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
                      onPressed: () => context.read<DeliveryCubit>().loadDisponibles(),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar',
                    ),
                  TextButton.icon(
                    onPressed: () => context.push(AppRoutes.deliveryQueueMap),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Ver en el mapa'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ..._buildQueue(context, state, profile, items),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildQueue(
    BuildContext context,
    DeliveryState state,
    profile,
    List<DeliveryEntregaModel> items,
  ) {
    if (profile == null) {
      return const [
        DeliveryMessageCard(
          message:
              'No tienes perfil delivery configurado. Registrate como repartidor '
              'para aceptar solicitudes.',
        ),
      ];
    }
    if (!profile.available) {
      return const [
        DeliveryMessageCard(
          message:
              'Activa tu disponibilidad desde el Panel para ver y aceptar solicitudes.',
        ),
      ];
    }
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
        DeliveryMessageCard(
          message:
              'No hay solicitudes disponibles por ahora.\n\nSolo aparecen los pedidos que el cliente pidio con reparto, dentro de tu radio de operacion y con tu disponibilidad activa.',
        ),
      ];
    }
    return items
        .map(
          (entrega) => AvailableDeliveryCard(
            entrega: entrega,
            accepting: state.acceptingEntregaId == entrega.id,
            rejecting: state.rechazandoEntregaId == entrega.id,
            onAccept: () => unawaited(_confirmAccept(entrega)),
            onStartRoute: () =>
                unawaited(_confirmAccept(entrega, startRoute: true)),
            onReject: () => unawaited(_confirmRechazar(entrega)),
          ),
        )
        .toList();
  }

  Future<void> _confirmAccept(
    DeliveryEntregaModel entrega, {
    bool startRoute = false,
  }) async {
    final currency = entrega.moneda ?? 'CUP';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aceptar solicitud'),
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
      if (startRoute) _autoOpenRouteAfterAccept = true;
      context.read<DeliveryCubit>().aceptar(entrega.id);
    }
  }

  Future<void> _confirmRechazar(DeliveryEntregaModel entrega) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechazar pedido'),
        content: const Text(
          'Esta solicitud sigue pendiente. Si la rechazas, el negocio y el cliente '
          'seran notificados y quedara disponible para otros repartidores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cubit = context.read<DeliveryCubit>();
    await cubit.rechazarEntrega(entrega.id);
    if (!mounted) return;
    final error = cubit.state.queueError;
    if (error != null && error.isNotEmpty) {
      showSnackOrAuthDialog(context, error);
    } else {
      showSnackOrAuthDialog(context, 'Pedido rechazado.');
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
              if (context.mounted) context.push(AppRoutes.deliveryRoute);
            },
            child: const Text('Ver ruta'),
          ),
        ],
      ),
    );
  }
}