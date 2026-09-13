import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/compact_date_range_dialog.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../orders/blocs/orders/orders_cubit.dart';
import '../../../orders/blocs/orders/orders_state.dart';
import '../../../orders/data/models/order_model.dart';
import '../../blocs/delivery/delivery_cubit.dart';
import '../../blocs/delivery/delivery_state.dart';
import '../../data/models/delivery_entrega_model.dart';
import '../../data/models/delivery_profile_model.dart';
import '../widgets/delivery_tracking_sheet.dart';
import 'delivery_route_screen.dart';

enum DeliveryHubSection { dashboard, requests, route, history, profile }

enum _DateFilter { all, today, last7, thisMonth }

const _deliveryTrackedStatuses = {
  'reservado_delivery',
  'delivery_asignado',
  'recogido_por_delivery',
  'en_ruta',
  'entregado_por_delivery',
  'recibido_cliente',
  'completado',
  'cancelado',
};

const _deliveryActiveTrackingStatuses = {
  'delivery_asignado',
  'recogido_por_delivery',
  'en_ruta',
};

const _deliveryStatusFiltersRequests = [
  _StatusOption(null, 'Todos'),
  _StatusOption('reservado_delivery', 'Reservado'),
  _StatusOption('delivery_asignado', 'Asignado'),
  _StatusOption('recogido_por_delivery', 'Recogido'),
  _StatusOption('en_ruta', 'En ruta'),
  _StatusOption('entregado_por_delivery', 'Entregado'),
];

const _deliveryStatusFiltersHistory = [
  _StatusOption(null, 'Todos'),
  _StatusOption('recibido_cliente', 'Recibido'),
  _StatusOption('completado', 'Completado'),
  _StatusOption('cancelado', 'Cancelado'),
];

const _deliveryShortStatusLabels = {
  'reservado_delivery': 'Reservado',
  'delivery_asignado': 'Asignado',
  'recogido_por_delivery': 'Recogido',
  'en_ruta': 'En ruta',
  'entregado_por_delivery': 'Entregado',
  'recibido_cliente': 'Recibido',
  'completado': 'Completado',
  'cancelado': 'Cancelado',
};

class DeliveryHubScreen extends StatelessWidget {
  const DeliveryHubScreen({required this.section, super.key});

  final DeliveryHubSection section;

  @override
  Widget build(BuildContext context) {
    if (section == DeliveryHubSection.dashboard) {
      return BlocProvider(
        create: (_) => sl<DeliveryCubit>()..load(),
        child: const _DeliveryDashboardView(),
      );
    }
    if (section == DeliveryHubSection.requests ||
        section == DeliveryHubSection.history) {
      return BlocProvider(
        create: (_) => sl<OrdersCubit>()..load(),
        child: _DeliveryOrdersView(section: section),
      );
    }
    if (section == DeliveryHubSection.route) {
      return const DeliveryRouteScreen();
    }
    if (section == DeliveryHubSection.profile) {
      return BlocProvider(
        create: (_) => sl<DeliveryCubit>()..load(),
        child: const _DeliveryProfileView(),
      );
    }
    return _DeliveryStaticView(section: section);
  }
}

class _DeliveryOrdersView extends StatefulWidget {
  const _DeliveryOrdersView({required this.section});

  final DeliveryHubSection section;

  @override
  State<_DeliveryOrdersView> createState() => _DeliveryOrdersViewState();
}

class _DeliveryOrdersViewState extends State<_DeliveryOrdersView> {
  _DateFilter _dateFilter = _DateFilter.all;
  String _clientQuery = '';
  String? _statusFilter;
  DateTimeRange? _customRange;
  bool _showSearch = false;
  bool _handledScanRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScanRefresh());
  }

  void _handleScanRefresh() {
    if (!mounted || _handledScanRefresh) return;
    final currentUri = GoRouterState.of(context).uri;
    final query = currentUri.queryParameters;
    if (query['scan'] != 'ok') return;
    _handledScanRefresh = true;

    final message = query['scan_msg'] ?? 'Pedido actualizado correctamente.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    context.read<OrdersCubit>().load();

    final cleanParams = Map<String, String>.from(query)
      ..remove('scan')
      ..remove('scan_msg');
    final cleanUri = Uri(
      path: currentUri.path,
      queryParameters: cleanParams.isEmpty ? null : cleanParams,
    );
    context.replace(cleanUri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isRequests = widget.section == DeliveryHubSection.requests;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showSearch = !_showSearch),
        child: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
      ),
      body: BlocConsumer<OrdersCubit, OrdersState>(
        listener: (context, state) {
          if (state.status == OrdersStatus.failure &&
              state.errorMessage != null) {
            showSnackOrAuthDialog(context, state.errorMessage);
          }
        },
        builder: (context, state) {
          final scoped = state.items.where((order) {
            if (!_deliveryTrackedStatuses.contains(order.status)) return false;
            final closed = const {
              'completado',
              'cerrado',
              'cancelado',
              'recibido_cliente',
            }.contains(order.status);
            return isRequests ? !closed : closed;
          });
          final visible = scoped.where(_matchesFilters).toList();

          return Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRequests
                            ? 'Solicitudes delivery'
                            : 'Historial delivery',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isRequests
                            ? 'Pedidos activos pendientes de recoger o entregar.'
                            : 'Pedidos cerrados, recibidos o cancelados.',
                      ),
                      if (_showSearch) ...[
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) =>
                              setState(() => _clientQuery = value.trim()),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            labelText: 'Buscar pedido',
                            hintText: 'Cliente o estado',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SelectActionButton(
                              title: 'Estado',
                              value: _statusLabel(_statusFilter),
                              icon: Icons.tune_rounded,
                              onPressed: _pickStatus,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SelectActionButton(
                              title: '',
                              value: _dateLabel(_dateFilter),
                              icon: Icons.event_note_outlined,
                              onPressed: _pickDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickCustomRange,
                              icon: const Icon(Icons.date_range_outlined),
                              label: Text(
                                _customRange == null
                                    ? 'Fechas'
                                    : 'Fechas: ${_formatDate(_customRange!.start)} - ${_formatDate(_customRange!.end)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_customRange != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _customRange = null),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Limpiar rango'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.status == OrdersStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return RefreshIndicator(
                      onRefresh: () => context.read<OrdersCubit>().load(),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (state.status == OrdersStatus.failure)
                            _MessageCard(
                              message:
                                  state.errorMessage ?? 'No se pudo cargar.',
                            )
                          else if (visible.isEmpty)
                            const _MessageCard(
                              message: 'No hay pedidos con esos filtros.',
                            )
                          else
                            ...visible.map(
                              (order) => _DeliveryOrderCard(order: order),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilters(OrderModel order) {
    final query = _clientQuery.toLowerCase();
    final searchable = [
      order.contactName,
      order.title,
      order.statusLabel,
      order.email,
    ].whereType<String>().join(' ').toLowerCase();
    final matchesClient = query.isEmpty || searchable.contains(query);
    final matchesStatus =
        _statusFilter == null || order.status == _statusFilter;
    return matchesClient && matchesStatus && _matchesDate(order.createdAt);
  }

  bool _matchesDate(DateTime? date) {
    if (date == null) {
      return _customRange == null && _dateFilter == _DateFilter.all;
    }
    if (_customRange != null) {
      final start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
      final end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day,
        23,
        59,
        59,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }
    if (_dateFilter == _DateFilter.all) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = DateTime(date.year, date.month, date.day);
    return switch (_dateFilter) {
      _DateFilter.today => value == today,
      _DateFilter.last7 => !value.isBefore(
        today.subtract(const Duration(days: 6)),
      ),
      _DateFilter.thisMonth =>
        value.year == today.year && value.month == today.month,
      _DateFilter.all => true,
    };
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showCompactDateRangeDialog(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialRange: _customRange,
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _dateFilter = _DateFilter.all;
    });
  }

  Future<void> _pickStatus() async {
    final selected = await _showSelectSheet<String>(
      title: 'Selecciona estado',
      options: _statusOptions
          .map(
            (item) => _SelectOption(value: item.value ?? '', label: item.label),
          )
          .toList(),
      currentValue: _statusFilter ?? '',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _statusFilter = selected.isEmpty ? null : selected;
    });
  }

  Future<void> _pickDate() async {
    final selected = await _showSelectSheet<_DateFilter>(
      title: 'Selecciona fecha',
      options: const [
        _SelectOption(value: _DateFilter.all, label: 'Todo el tiempo'),
        _SelectOption(value: _DateFilter.today, label: 'Hoy'),
        _SelectOption(value: _DateFilter.last7, label: 'Ultimos 7 dias'),
        _SelectOption(value: _DateFilter.thisMonth, label: 'Este mes'),
      ],
      currentValue: _dateFilter,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _dateFilter = selected;
      _customRange = null;
    });
  }

  Future<T?> _showSelectSheet<T>({
    required String title,
    required List<_SelectOption<T>> options,
    required T currentValue,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ...options.map((item) {
                final selected = item.value == currentValue;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(item.label),
                  onTap: () => Navigator.of(sheetContext).pop(item.value),
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String? value) {
    for (final item in _statusOptions) {
      if ((item.value ?? '') == (value ?? '')) return item.label;
    }
    return 'Todos';
  }

  List<_StatusOption> get _statusOptions =>
      widget.section == DeliveryHubSection.requests
      ? _deliveryStatusFiltersRequests
      : _deliveryStatusFiltersHistory;

  String _dateLabel(_DateFilter value) {
    return switch (value) {
      _DateFilter.all => 'Todo el tiempo',
      _DateFilter.today => 'Hoy',
      _DateFilter.last7 => 'Ultimos 7 dias',
      _DateFilter.thisMonth => 'Este mes',
    };
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _DeliveryDashboardView extends StatefulWidget {
  const _DeliveryDashboardView();

  @override
  State<_DeliveryDashboardView> createState() => _DeliveryDashboardViewState();
}

class _DeliveryDashboardViewState extends State<_DeliveryDashboardView> {
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
                  _MetaChip(
                    icon: Icons.local_shipping_outlined,
                    label: profile.vehicleType ?? 'Sin vehiculo',
                  ),
                  _MetaChip(
                    icon: Icons.speed_rounded,
                    label:
                        'Tarifa ${profile.baseRate.toStringAsFixed(0)} + ${profile.perKmRate.toStringAsFixed(0)}/km',
                  ),
                  _MetaChip(
                    icon: Icons.radar_rounded,
                    label:
                        'Radio ${profile.operatingRadiusKm.toStringAsFixed(0)} km',
                  ),
                  _MetaChip(
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
        _MessageCard(
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
        _MessageCard(message: 'No hay entregas disponibles por ahora.'),
      ];
    }
    return items
        .map(
          (entrega) => _AvailableEntregaCard(
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
                'Distancia estimada: ${_formatDistance(entrega.distanciaTotalKm)}',
              ),
              Text(
                'Tarifa estimada: ${_formatMoney(entrega.tarifaEstimada, currency)}',
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
            Text('Distancia: ${_formatDistance(entrega.distanciaTotalKm)}'),
            Text(
              'Tarifa estimada: ${_formatMoney(entrega.tarifaEstimada, currency)}',
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

class _AvailableEntregaCard extends StatelessWidget {
  const _AvailableEntregaCard({
    required this.entrega,
    required this.accepting,
    required this.onAccept,
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
                _StatusPill(status: 'reservado_delivery', label: 'Solicitado'),
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
                _MetaChip(
                  icon: Icons.payments_outlined,
                  label: _formatMoney(entrega.tarifaEstimada, currency),
                ),
                _MetaChip(
                  icon: Icons.straighten_rounded,
                  label: _formatDistance(entrega.distanciaTotalKm),
                ),
                _MetaChip(
                  icon: Icons.near_me_rounded,
                  label: 'A ${_formatDistance(entrega.distanciaAlOrigenKm)}',
                ),
                _MetaChip(
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

class _DeliveryOrderCard extends StatelessWidget {
  const _DeliveryOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final total = order.estimatedTotal == null
        ? 'Consultar'
        : '${order.estimatedTotal!.toStringAsFixed(0)} ${order.currency ?? 'CUP'}';
    final created = order.createdAt == null
        ? '-'
        : '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year}';
    final imageUrl = order.primaryImageUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _OrderThumbnail(
                  imageUrl: imageUrl,
                  fallbackIcon: _iconFor(order.type),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(
                  label: _shortDeliveryStatusLabel(
                    order.status,
                    order.statusLabel,
                  ),
                  status: order.status,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.person_outline_rounded,
                  label: order.contactName ?? 'Sin nombre',
                ),
                _MetaChip(icon: Icons.calendar_today_outlined, label: created),
                _MetaChip(icon: Icons.payments_outlined, label: total),
                if (order.tarifaCobrada != null)
                  _MetaChip(
                    icon: Icons.savings_outlined,
                    label:
                        'Tarifa cobrada: ${_formatMoney(order.tarifaCobrada, order.currency ?? 'CUP')}',
                  ),
                _MetaChip(
                  icon: Icons.tag_rounded,
                  label: 'Cantidad ${order.quantity ?? 1}',
                ),
                if ((order.typeLabel).isNotEmpty)
                  _MetaChip(
                    icon: Icons.category_outlined,
                    label: order.typeLabel,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_deliveryActiveTrackingStatuses.contains(order.status))
              OutlinedButton.icon(
                onPressed: () => showDeliveryTrackingSheet(context, order.id),
                icon: const Icon(Icons.near_me_rounded),
                label: const Text('Ver ubicacion del repartidor'),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'producto' => Icons.inventory_2_outlined,
      'propiedad' => Icons.home_work_outlined,
      'transporte' => Icons.local_shipping_outlined,
      'servicio' => Icons.handyman_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }
}

class _DeliveryProfileView extends StatelessWidget {
  const _DeliveryProfileView();

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
                _ProfileSummaryCard(profile: profile),
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

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

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
                    _vehicleIcon(profile.vehicleType),
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
                _StatusPill(
                  label: profile.available ? 'Disponible' : 'Offline',
                  status: profile.available ? 'completado' : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetaChip(
              icon: Icons.payments_outlined,
              label:
                  'Base ${_formatMoney(profile.baseRate)} + '
                  '${_formatMoney(profile.perKmRate)}/km',
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.local_shipping_outlined,
                  label: profile.vehicleType ?? 'Sin vehiculo',
                ),
                if (profile.plate != null && profile.plate!.isNotEmpty)
                  _MetaChip(
                    icon: Icons.badge_outlined,
                    label: 'Placa: ${profile.plate}',
                  ),
                _MetaChip(
                  icon: Icons.speed_rounded,
                  label:
                      'Radio ${profile.operatingRadiusKm.toStringAsFixed(0)} km',
                ),
                if (profile.averageRating != null)
                  _MetaChip(
                    icon: Icons.star_rounded,
                    label: profile.averageRating!.toStringAsFixed(1),
                  ),
                _MetaChip(
                  icon: Icons.verified_outlined,
                  label: profile.active ? 'Perfil activo' : 'Perfil inactivo',
                ),
                _MetaChip(
                  icon: Icons.workspace_premium_outlined,
                  label:
                      'Confianza: ${trustLevel[0].toUpperCase()}${trustLevel.substring(1)}',
                ),
                _MetaChip(
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

  String _formatMoney(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  IconData _vehicleIcon(String? vehiculo) {
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

class _DeliveryStaticView extends StatelessWidget {
  const _DeliveryStaticView({required this.section});

  final DeliveryHubSection section;

  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      DeliveryHubSection.dashboard => 'Panel delivery',
      DeliveryHubSection.route => 'Ruta y mapa',
      DeliveryHubSection.profile => 'Perfil delivery',
      DeliveryHubSection.requests => 'Solicitudes',
      DeliveryHubSection.history => 'Historial delivery',
    };
    final subtitle = switch (section) {
      DeliveryHubSection.dashboard =>
        'Solicitudes, entregas y estado operativo.',
      DeliveryHubSection.route =>
        'Seguimiento en tiempo real y validaciones QR.',
      DeliveryHubSection.profile =>
        'Vehiculo, tarifas, verificacion y disponibilidad.',
      DeliveryHubSection.requests =>
        'Pedidos de tiendas y paquetes entre clientes.',
      DeliveryHubSection.history => 'Entregas cerradas y pedidos completados.',
    };

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _SelectActionButton extends StatelessWidget {
  const _SelectActionButton({
    required this.title,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
        ],
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectOption<T> {
  const _SelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.label});

  final String? status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = switch (status) {
      'completado' ||
      'cerrado' => _StatusVisual(Colors.green, Icons.check_circle_rounded),
      'cancelado' => _StatusVisual(
        Theme.of(context).colorScheme.error,
        Icons.cancel_rounded,
      ),
      'en_ruta' || 'delivery_asignado' || 'recogido_por_delivery' =>
        _StatusVisual(Colors.blue, Icons.local_shipping_rounded),
      'entregado_por_delivery' || 'recibido_cliente' => _StatusVisual(
        Colors.teal,
        Icons.qr_code_scanner_rounded,
      ),
      _ => _StatusVisual(
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

class _StatusVisual {
  const _StatusVisual(this.color, this.icon);

  final Color color;
  final IconData icon;
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.imageUrl, required this.fallbackIcon});

  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.secondary,
      foregroundColor: Theme.of(context).colorScheme.onSecondary,
      child: imageUrl == null
          ? Icon(fallbackIcon, size: 18)
          : ClipOval(
              child: Image.network(
                imageUrl!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(fallbackIcon, size: 18),
              ),
            ),
    );
  }
}

String _shortDeliveryStatusLabel(String? status, String fallback) {
  if (status == null || status.isEmpty) return fallback;
  return _deliveryShortStatusLabels[status] ?? fallback;
}

String _formatDistance(double? km) {
  if (km == null) return '-';
  if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
  return '${km.toStringAsFixed(1)} km';
}

String _formatMoney(double? value, String currency) {
  if (value == null) return 'Consultar $currency';
  return '${value.toStringAsFixed(2)} $currency';
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

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

class _StatusOption {
  const _StatusOption(this.value, this.label);

  final String? value;
  final String label;
}
