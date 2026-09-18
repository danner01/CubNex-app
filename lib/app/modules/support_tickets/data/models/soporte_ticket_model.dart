class SoporteTicketModel {
  const SoporteTicketModel({
    required this.id,
    this.numeroTicket,
    this.titulo,
    required this.descripcion,
    this.adjuntoUrl,
    required this.estado,
    this.resolucion,
    this.createdAt,
    this.usuarioNombre,
    this.usuarioEmail,
    this.usuarioTelefono,
  });

  final String id;
  final int? numeroTicket;
  final String? titulo;
  final String descripcion;
  final String? adjuntoUrl;
  final String estado;
  final String? resolucion;
  final DateTime? createdAt;
  final String? usuarioNombre;
  final String? usuarioEmail;
  final String? usuarioTelefono;

  bool get esPendiente => estado == 'pendiente';
  bool get esResuelto => estado == 'resuelto';
  bool get esCancelado => estado == 'cancelado';
  bool get estaAtendido => esResuelto || esCancelado;

  factory SoporteTicketModel.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];
    final usuarioMap = usuario is Map<String, dynamic>
        ? usuario
        : usuario is Map
            ? Map<String, dynamic>.from(usuario)
            : null;
    return SoporteTicketModel(
      id: '${json['id'] ?? ''}',
      numeroTicket: json['numero_ticket'] is num
          ? (json['numero_ticket'] as num).toInt()
          : int.tryParse('${json['numero_ticket'] ?? ''}'),
      titulo: json['titulo']?.toString(),
      descripcion: '${json['descripcion'] ?? ''}',
      adjuntoUrl: json['adjunto_url']?.toString(),
      estado: '${json['estado'] ?? 'pendiente'}',
      resolucion: json['resolucion']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      usuarioNombre: usuarioMap?['nombre_completo']?.toString(),
      usuarioEmail: usuarioMap?['email']?.toString(),
      usuarioTelefono: usuarioMap?['telefono']?.toString(),
    );
  }
}