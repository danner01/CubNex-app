import 'credit_movement.dart';

class CreditSummary {
  const CreditSummary({
    required this.balance,
    required this.availableBalance,
    required this.totalEarned,
    required this.totalSpent,
    this.grains = 0,
    this.alias,
    this.qrPayload,
    this.recentMovements = const [],
    this.actionBreakdown = const {},
  });

  final int balance;
  final int availableBalance;
  final int totalEarned;
  final int totalSpent;
  final int grains;
  final String? alias;
  final String? qrPayload;
  final List<CreditMovement> recentMovements;
  final Map<String, int> actionBreakdown;

  factory CreditSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}') ?? 0;
    }

    final summary = json['resumen'] is Map
        ? Map<String, dynamic>.from(json['resumen'] as Map)
        : json['datos'] is Map
            ? Map<String, dynamic>.from(json['datos'] as Map)
            : Map<String, dynamic>.from(json);

    final movementsData =
        json['movimientos'] ?? json['transacciones'] ?? json['historial'];

    final actionBreakdown = <String, int>{};
    final rawBreakdown = summary['accion_breakdown'] ??
        summary['desglose'] ??
        summary['breakdown'];
    if (rawBreakdown is Map) {
      for (final entry in rawBreakdown.entries) {
        actionBreakdown[entry.key.toString()] = parseInt(entry.value);
      }
    }

    return CreditSummary(
      balance: parseInt(
        summary['saldo'] ??
            summary['balance'] ??
            summary['creditos'] ??
            summary['creditos_disponibles'] ??
            0,
      ),
      availableBalance: parseInt(
        summary['saldo_disponible'] ??
            summary['balance_disponible'] ??
            summary['creditos_disponibles'] ??
            summary['credito_disponible'] ??
            summary['saldo'] ??
            0,
      ),
      totalEarned: parseInt(
        summary['total_ganado'] ??
            summary['ganado'] ??
            summary['creditos_ganados'] ??
            0,
      ),
      totalSpent: parseInt(
        summary['total_gastado'] ??
            summary['gastado'] ??
            summary['creditos_utilizados'] ??
            0,
      ),
      grains: parseInt(
        summary['granos'] ??
            summary['granos_acumulados'] ??
            json['granos'] ??
            json['granos_acumulados'] ??
            0,
      ),
      alias: (summary['alias'] ??
              json['alias'] ??
              json['email'] ??
              summary['email'])
          ?.toString(),
      qrPayload: (summary['qr_payload'] ??
              summary['qr'] ??
              json['qr_payload'] ??
              json['qr'])
          ?.toString(),
      recentMovements: movementsData is List
          ? movementsData
              .whereType<Map>()
              .map(
                (item) =>
                    CreditMovement.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
          : const [],
      actionBreakdown: actionBreakdown,
    );
  }
}
