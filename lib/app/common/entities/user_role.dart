enum UserRole {
  guest,
  client,
  delivery,
  businessAdmin,
  superadmin;

  static UserRole fromApi(String? value) {
    return switch (value) {
      'admin_negocio' => UserRole.businessAdmin,
      'delivery' => UserRole.delivery,
      'repartidor' => UserRole.delivery,
      'superadmin' => UserRole.superadmin,
      'cliente' => UserRole.client,
      _ => UserRole.guest,
    };
  }

  String get apiValue {
    return switch (this) {
      UserRole.businessAdmin => 'admin_negocio',
      UserRole.delivery => 'delivery',
      UserRole.superadmin => 'superadmin',
      UserRole.client => 'cliente',
      UserRole.guest => 'invitado',
    };
  }
}
