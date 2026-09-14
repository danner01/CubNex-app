import 'package:flutter/material.dart';

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

String formatDeliveryDistance(double? km) {
  if (km == null) return '-';
  if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
  return '${km.toStringAsFixed(1)} km';
}

String formatDeliveryMoney(double? value, String currency) {
  if (value == null) return 'Consultar $currency';
  return '${value.toStringAsFixed(2)} $currency';
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
