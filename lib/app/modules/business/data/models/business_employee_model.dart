import '../../../../common/entities/employee_permissions.dart';

class BusinessEmployeeModel {
  const BusinessEmployeeModel({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.roleTitle,
    required this.status,
    required this.permissions,
    this.isDelivery = false,
    this.inviteMessage,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userAvatarUrl,
    this.businessName,
    this.businessLogoUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String userId;
  final String roleTitle;
  final String status;
  final Map<String, bool> permissions;
  final bool isDelivery;
  final String? inviteMessage;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userAvatarUrl;
  final String? businessName;
  final String? businessLogoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'activo';
  bool get isPending => status == 'pendiente';

  bool can(String permission) =>
      EmployeePermissionKeys.allows(permissions, permission);

  factory BusinessEmployeeModel.fromJson(Map<String, dynamic> json) {
    final user = json['usuario'] is Map
        ? Map<String, dynamic>.from(json['usuario'] as Map)
        : json['perfiles'] is Map
        ? Map<String, dynamic>.from(json['perfiles'] as Map)
        : const <String, dynamic>{};
    final business = json['negocio'] is Map
        ? Map<String, dynamic>.from(json['negocio'] as Map)
        : json['negocios'] is Map
        ? Map<String, dynamic>.from(json['negocios'] as Map)
        : const <String, dynamic>{};

    final rawPermissions = json['permisos'];
    final permissionsMap = rawPermissions is Map
        ? Map<String, dynamic>.from(rawPermissions)
        : null;

    return BusinessEmployeeModel(
      id: '${json['id'] ?? ''}',
      businessId: '${json['negocio_id'] ?? business['id'] ?? ''}',
      userId: '${json['usuario_id'] ?? user['id'] ?? ''}',
      roleTitle: '${json['cargo'] ?? 'Empleado'}',
      status: '${json['estado'] ?? 'pendiente'}',
      permissions: EmployeePermissionKeys.normalize(permissionsMap),
      isDelivery: json['es_delivery'] == true,
      inviteMessage: json['mensaje_invitacion']?.toString(),
      userName:
          user['nombre_completo']?.toString() ??
          user['full_name']?.toString() ??
          json['usuario_nombre']?.toString(),
      userEmail: user['email']?.toString() ?? json['usuario_email']?.toString(),
      userPhone:
          user['telefono']?.toString() ?? json['usuario_telefono']?.toString(),
      userAvatarUrl:
          user['avatar_url']?.toString() ??
          json['usuario_avatar_url']?.toString(),
      businessName:
          business['nombre']?.toString() ?? json['negocio_nombre']?.toString(),
      businessLogoUrl:
          business['logo_url']?.toString() ??
          json['negocio_logo_url']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'cargo': roleTitle,
      'estado': status,
      'es_delivery': isDelivery,
      'permisos': permissions,
    };
  }
}
