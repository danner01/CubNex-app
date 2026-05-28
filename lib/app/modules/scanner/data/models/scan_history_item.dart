class ScanHistoryItem {
  const ScanHistoryItem({
    required this.id,
    required this.type,
    required this.content,
    this.productId,
    this.businessId,
    this.createdAt,
  });

  final String id;
  final String type;
  final String content;
  final String? productId;
  final String? businessId;
  final DateTime? createdAt;

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: '${json['id'] ?? ''}',
      type: '${json['tipo'] ?? 'codigo_barras'}',
      content: '${json['contenido'] ?? ''}',
      productId: json['producto_encontrado_id']?.toString(),
      businessId: json['negocio_id']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
