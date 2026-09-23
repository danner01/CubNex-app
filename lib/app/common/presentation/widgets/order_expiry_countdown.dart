import 'dart:async';

import 'package:flutter/material.dart';

class OrderExpiryCountdown extends StatefulWidget {
  const OrderExpiryCountdown({
    required this.expiresAt,
    this.expiredLabel = 'Pedido caducado',
    super.key,
  });

  final DateTime expiresAt;
  final String expiredLabel;

  @override
  State<OrderExpiryCountdown> createState() => _OrderExpiryCountdownState();
}

class _OrderExpiryCountdownState extends State<OrderExpiryCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final expired = remaining.inSeconds <= 0;
    final danger = !expired && remaining.inMinutes <= 60;
    final color = expired
        ? Theme.of(context).colorScheme.error
        : danger
        ? Colors.orange.shade700
        : Colors.green.shade700;
    final label = expired
        ? widget.expiredLabel
        : 'Caduca en ${_formatDuration(remaining)} · ${_friendlyRemainingLabel(remaining)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    final safe = value.isNegative ? Duration.zero : value;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _friendlyRemainingLabel(Duration value) {
    final safe = value.isNegative ? Duration.zero : value;
    if (safe.inDays >= 1) {
      final days = safe.inDays;
      return '$days ${days == 1 ? 'dia' : 'dias'} restantes';
    }
    if (safe.inHours >= 1) {
      final hours = safe.inHours;
      return '$hours ${hours == 1 ? 'hora' : 'horas'} restantes';
    }
    final minutes = safe.inMinutes;
    return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'} restantes';
  }
}