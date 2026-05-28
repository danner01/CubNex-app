class GamificationSummary {
  const GamificationSummary({
    required this.points,
    required this.level,
    required this.totalPurchases,
    required this.totalReviews,
    this.profileName,
    this.recentMovements = const [],
  });

  final int points;
  final String level;
  final int totalPurchases;
  final int totalReviews;
  final String? profileName;
  final List<PointMovement> recentMovements;

  factory GamificationSummary.fromJson(Map<String, dynamic> json) {
    final profile = json['perfil'] is Map
        ? Map<String, dynamic>.from(json['perfil'] as Map)
        : <String, dynamic>{};
    final movements = json['movimientos_recientes'];

    return GamificationSummary(
      points: _int(profile['puntos_acumulados']),
      level: '${profile['nivel'] ?? 'bronce'}',
      totalPurchases: _int(profile['total_compras']),
      totalReviews: _int(profile['total_resenas']),
      profileName: profile['nombre_completo']?.toString(),
      recentMovements: movements is List
          ? movements
                .whereType<Map>()
                .map(
                  (item) =>
                      PointMovement.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }
}

class PointMovement {
  const PointMovement({
    required this.id,
    required this.type,
    required this.points,
    this.description,
    this.createdAt,
  });

  final String id;
  final String type;
  final int points;
  final String? description;
  final DateTime? createdAt;

  factory PointMovement.fromJson(Map<String, dynamic> json) {
    return PointMovement(
      id: '${json['id'] ?? ''}',
      type: '${json['tipo'] ?? 'bonus'}',
      points: GamificationSummary._int(json['puntos']),
      description: json['descripcion']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
