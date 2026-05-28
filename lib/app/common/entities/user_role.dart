enum UserRole {
  guest,
  client,
  businessAdmin,
  superadmin;

  static UserRole fromApi(String? value) {
    return switch (value) {
      'admin_negocio' => UserRole.businessAdmin,
      'superadmin' => UserRole.superadmin,
      'cliente' => UserRole.client,
      _ => UserRole.guest,
    };
  }
}
