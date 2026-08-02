class CreditMovement {
  const CreditMovement({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    this.balanceAfter,
    this.createdAt,
  });

  final String id;
  final String type;
  final int amount;
  final String? description;
  final int? balanceAfter;
  final DateTime? createdAt;

  factory CreditMovement.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}') ?? 0;
    }

    return CreditMovement(
      id: '${json['id'] ?? json['movimiento_id'] ?? ''}',
      type: '${json['tipo'] ?? json['tipo_movimiento'] ?? 'credito'}',
      amount: parseInt(json['monto'] ?? json['cantidad'] ?? json['valor'] ?? 0),
      description: json['descripcion']?.toString() ??
          json['detalle']?.toString() ??
          json['mensaje']?.toString(),
      balanceAfter: json['saldo_restante'] is num
          ? (json['saldo_restante'] as num).toInt()
          : int.tryParse('${json['saldo_restante'] ?? json['saldo'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['created_at'] ?? json['fecha'] ?? ''}'),
    );
  }
}
