class WalletReceivingAccount {
  const WalletReceivingAccount({
    required this.type,
    required this.holder,
    this.bank,
    this.accountNumber,
    this.cardNumber,
    this.instructions,
  });

  final String type;
  final String holder;
  final String? bank;
  final String? accountNumber;
  final String? cardNumber;
  final String? instructions;

  factory WalletReceivingAccount.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      final parsed = value?.toString().trim();
      return parsed == null || parsed.isEmpty ? null : parsed;
    }

    return WalletReceivingAccount(
      type: text(json['tipo']) ?? 'transferencia_bancaria',
      holder: text(json['titular']) ?? 'ConKkao',
      bank: text(json['banco']),
      accountNumber: text(json['numero_cuenta']),
      cardNumber: text(json['tarjeta']),
      instructions: text(json['instrucciones']),
    );
  }
}

class VerifiedTopupRequest {
  const VerifiedTopupRequest({
    required this.id,
    required this.status,
    required this.walletScope,
    required this.amount,
    this.businessId,
    this.reference,
    this.createdAt,
    this.processedAt,
    this.adminNotes,
  });

  final String id;
  final String status;
  final String walletScope;
  final int amount;
  final String? businessId;
  final String? reference;
  final DateTime? createdAt;
  final DateTime? processedAt;
  final String? adminNotes;

  factory VerifiedTopupRequest.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}') ?? 0;
    }

    String? text(Object? value) {
      final parsed = value?.toString().trim();
      return parsed == null || parsed.isEmpty ? null : parsed;
    }

    return VerifiedTopupRequest(
      id: text(json['id'] ?? json['solicitud_id']) ?? '',
      status: text(json['estado']) ?? 'pendiente',
      walletScope: text(json['wallet_destino']) ?? 'personal',
      amount: asInt(
        json['granos_solicitados'] ??
            json['creditos_solicitados'] ??
            json['monto_cup'],
      ),
      businessId: text(json['negocio_id']),
      reference: text(json['referencia_pago']),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      processedAt: DateTime.tryParse('${json['procesado_at'] ?? ''}'),
      adminNotes: text(json['notas_admin']),
    );
  }
}
