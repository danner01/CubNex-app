import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../delivery/data/models/delivery_entrega_model.dart';
import '../../data/models/order_model.dart';

/// Muestra en la tarjeta de un pedido los datos reales del envio en vivo:
/// distancia por calles, tiempo estimado, costo y aviso de retorno de dinero.
///
/// Se alimenta de `GET /entregas/:id`, que ya calcula la ruta real (Mapbox)
/// con distancia y duracion cuando el repartidor la tiene. Reconsulta cada
/// 30s mientras el pedido esta activo y mantiene un contador en vivo del
/// tiempo estimado de la entrega.
class OrderDeliveryMetricsCard extends StatefulWidget {
  const OrderDeliveryMetricsCard({required this.order, super.key});

  final OrderModel order;

  @override
  State<OrderDeliveryMetricsCard> createState() =>
      _OrderDeliveryMetricsCardState();
}

class _OrderDeliveryMetricsCardState extends State<OrderDeliveryMetricsCard> {
  static const _pollInterval = Duration(seconds: 30);

  final ApiClient _apiClient = sl<ApiClient>();

  DeliveryEntregaModel? _entrega;
  bool _loading = true;
  double? _lastDurationSeconds;
  DateTime? _etaTarget;
  Timer? _pollTimer;
  Timer? _tickTimer;

  bool get _enabled =>
      widget.order.entregaId != null &&
      _isActiveDeliveryStatus(widget.order.status);

  @override
  void initState() {
    super.initState();
    _startIfEnabled();
  }

  @override
  void didUpdateWidget(OrderDeliveryMetricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entregaChanged =
        oldWidget.order.entregaId != widget.order.entregaId;
    final statusChanged = oldWidget.order.status != widget.order.status;
    if (!entregaChanged && !statusChanged) return;
    if (_enabled) {
      _startIfEnabled(reset: entregaChanged || _entrega == null);
      return;
    }
    _stopTimers();
    _etaTarget = null;
    _lastDurationSeconds = null;
    if (mounted) {
      setState(() {
        _entrega = null;
        _loading = true;
      });
    }
  }

  void _startIfEnabled({bool reset = false}) {
    if (!_enabled) return;
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => unawaited(_fetch()));
    _tickTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted && _etaTarget != null) setState(() {});
      },
    );
    if (reset) {
      _etaTarget = null;
      _lastDurationSeconds = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_fetch()));
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  Future<void> _fetch() async {
    final entregaId = widget.order.entregaId;
    if (entregaId == null || !_enabled) return;
    final result = await _apiClient.get<DeliveryEntregaModel?>(
      '/entregas/$entregaId',
      parser: (json) {
        if (json is! Map) return null;
        return DeliveryEntregaModel.fromJson(Map<String, dynamic>.from(json));
      },
    );
    if (!mounted) return;
    final data = result.data;
    if (!result.isSuccess || data == null) {
      setState(() => _loading = false);
      return;
    }
    final duration = data.rutaDurationSeconds;
    final changed = duration != _lastDurationSeconds;
    setState(() {
      _loading = false;
      _entrega = data;
      if (duration != null && duration > 0) {
        _lastDurationSeconds = duration;
        if (changed || _etaTarget == null) {
          _etaTarget = DateTime.now().add(
            Duration(seconds: duration.round()),
          );
        }
      } else {
        _lastDurationSeconds = null;
        _etaTarget = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();
    final theme = Theme.of(context);

    if (_loading && _entrega == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Calculando envio...',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final entrega = _entrega;
    if (entrega == null) return const SizedBox.shrink();

    final rutaKm = entrega.rutaDistanceKm;
    final distanciaKm = rutaKm ?? entrega.distanciaTotalKm;
    final minutos = entrega.rutaDurationSeconds == null
        ? null
        : entrega.rutaDurationSeconds! / 60;
    final currency = entrega.moneda ?? 'CUP';
    final costo = _computeCosto(entrega, rutaKm);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Envio y reparto',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                theme,
                Icons.straighten_rounded,
                _formatDistance(distanciaKm),
              ),
              if (minutos != null)
                _chip(
                  theme,
                  Icons.schedule_rounded,
                  _formatMinutes(minutos),
                ),
              if (costo != null)
                _chip(
                  theme,
                  Icons.payments_outlined,
                  '${costo.toStringAsFixed(2)} $currency',
                ),
              if (entrega.requiereRetornoDinero)
                _chip(
                  theme,
                  Icons.autorenew_rounded,
                  'Retorno de dinero',
                  color: theme.colorScheme.error,
                ),
            ],
          ),
          if (_etaText() != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _etaText()!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (_arrivalLabel() != null)
                  Text(
                    _arrivalLabel()!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double? _computeCosto(DeliveryEntregaModel entrega, double? rutaKm) {
    if ((entrega.paqueteTarifa ?? 0) > 0) return entrega.paqueteTarifa;
    if (rutaKm != null && (entrega.tarifaBase > 0 || entrega.tarifaPorKm > 0)) {
      return entrega.tarifaBase + entrega.tarifaPorKm * rutaKm;
    }
    return entrega.tarifaEstimada ?? entrega.tarifaTotal ?? entrega.montoACobrar;
  }

  String? _etaText() {
    final target = _etaTarget;
    if (target == null) return null;
    var remaining = target.difference(DateTime.now());
    if (remaining.isNegative) remaining = Duration.zero;
    if (remaining.inSeconds <= 0) return 'Entrega estimada: inminente';
    return 'Entrega estimada en ${_formatClock(remaining)}';
  }

  String? _arrivalLabel() {
    final target = _etaTarget;
    if (target == null) return null;
    return 'Llega ~${target.hour.toString().padLeft(2, '0')}:'
        '${target.minute.toString().padLeft(2, '0')}';
  }

  String _formatClock(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Widget _chip(
    ThemeData theme,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final chipColor = color ?? theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  bool _isActiveDeliveryStatus(String? status) {
    return switch (status) {
      'reservado_delivery' ||
      'confirmado_negocio' ||
      'preparando' ||
      'listo_para_recoger' ||
      'delivery_asignado' ||
      'recogido_por_delivery' ||
      'en_ruta' ||
      'entregado_por_delivery' ||
      'recibido_cliente' => true,
      _ => false,
    };
  }

  String _formatDistance(double? km) {
    if (km == null || !km.isFinite) return '-';
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatMinutes(double minutes) {
    if (minutes < 1) return '${(minutes * 60).toStringAsFixed(0)} min';
    return '${minutes.toStringAsFixed(0)} min';
  }
}