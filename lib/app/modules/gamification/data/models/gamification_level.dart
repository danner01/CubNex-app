class GamificationLevel {
  const GamificationLevel({required this.name, required this.minimumPoints});

  final String name;
  final int minimumPoints;

  factory GamificationLevel.fromJson(Map<String, dynamic> json) {
    return GamificationLevel(
      name: '${json['nivel'] ?? 'bronce'}',
      minimumPoints: _int(json['puntos_minimos']),
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }
}
