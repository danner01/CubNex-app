import 'package:flutter/material.dart';

Future<DateTimeRange?> showCompactDateRangeDialog({
  required BuildContext context,
  DateTimeRange? initialRange,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  final minDate = firstDate ?? DateTime(now.year - 3);
  final maxDate = lastDate ?? DateTime(now.year + 1);

  return showDialog<DateTimeRange>(
    context: context,
    builder: (dialogContext) {
      var start = initialRange?.start;
      var end = initialRange?.end;

      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickStart() async {
            final picked = await showDatePicker(
              context: context,
              locale: const Locale('es'),
              initialDate: start ?? end ?? now,
              firstDate: minDate,
              lastDate: maxDate,
              helpText: 'Selecciona la fecha inicial',
              cancelText: 'Cancelar',
              confirmText: 'Aceptar',
            );
            if (picked == null) return;
            setState(() {
              start = picked;
              if (end != null && end!.isBefore(start!)) {
                end = start;
              }
            });
          }

          Future<void> pickEnd() async {
            final picked = await showDatePicker(
              context: context,
              locale: const Locale('es'),
              initialDate: end ?? start ?? now,
              firstDate: minDate,
              lastDate: maxDate,
              helpText: 'Selecciona la fecha final',
              cancelText: 'Cancelar',
              confirmText: 'Aceptar',
            );
            if (picked == null) return;
            setState(() {
              end = picked;
              if (start != null && end!.isBefore(start!)) {
                start = end;
              }
            });
          }

          return AlertDialog(
            title: const Text('Rango de fechas'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona un rango personalizado sin salir de esta vista.',
                  ),
                  const SizedBox(height: 16),
                  _DateFieldButton(
                    label: 'Desde',
                    value: start,
                    icon: Icons.event_available_outlined,
                    onPressed: pickStart,
                  ),
                  const SizedBox(height: 12),
                  _DateFieldButton(
                    label: 'Hasta',
                    value: end,
                    icon: Icons.event_outlined,
                    onPressed: pickEnd,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: start == null || end == null
                    ? null
                    : () => Navigator.of(
                        dialogContext,
                      ).pop(DateTimeRange(start: start!, end: end!)),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _DateFieldButton extends StatelessWidget {
  const _DateFieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value == null ? 'Seleccionar fecha' : _formatDate(value!),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
