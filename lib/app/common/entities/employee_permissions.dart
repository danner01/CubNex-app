class EmployeePermissionKeys {
  const EmployeePermissionKeys._();

  static const verPanel = 'ver_panel';
  static const gestionarInventario = 'gestionar_inventario';
  static const crearProductos = 'crear_productos';
  static const editarProductos = 'editar_productos';
  static const gestionarPedidos = 'gestionar_pedidos';
  static const escanearPedidos = 'escanear_pedidos';
  static const pagosQr = 'pagos_qr';
  static const pagosAlias = 'pagos_alias';
  static const transferirCreditos = 'transferir_creditos';
  static const gestionarDelivery = 'gestionar_delivery';
  static const verReportes = 'ver_reportes';
  static const gestionarPromociones = 'gestionar_promociones';
  static const gestionarPublicaciones = 'gestionar_publicaciones';
  static const gestionarCampanasPagadas = 'gestionar_campanas_pagadas';
  static const gestionarPresupuestoPublicitario =
      'gestionar_presupuesto_publicitario';
  static const gestionarRed = 'gestionar_red';
  static const gestionarMenus = 'gestionar_menus';
  static const gestionarEmpleados = 'gestionar_empleados';
  static const editarNegocio = 'editar_negocio';
  static const gestionarEmpleos = 'gestionar_empleos';

  static const all = <String>[
    verPanel,
    gestionarInventario,
    crearProductos,
    editarProductos,
    gestionarPedidos,
    escanearPedidos,
    pagosQr,
    pagosAlias,
    transferirCreditos,
    gestionarDelivery,
    verReportes,
    gestionarPromociones,
    gestionarPublicaciones,
    gestionarCampanasPagadas,
    gestionarPresupuestoPublicitario,
    gestionarRed,
    gestionarMenus,
    gestionarEmpleados,
    editarNegocio,
    gestionarEmpleos,
  ];

  static const labels = <String, String>{
    verPanel: 'Ver panel de negocio',
    gestionarInventario: 'Gestionar inventario',
    crearProductos: 'Crear productos',
    editarProductos: 'Editar productos',
    gestionarPedidos: 'Gestionar pedidos',
    escanearPedidos: 'Escanear pedidos / QR',
    pagosQr: 'Cobros y pagos por QR',
    pagosAlias: 'Pagos por alias',
    transferirCreditos: 'Transferir creditos',
    gestionarDelivery: 'Gestionar delivery',
    verReportes: 'Ver reportes y metricas',
    gestionarPromociones: 'Gestionar promociones',
    gestionarPublicaciones: 'Gestionar publicaciones',
    gestionarCampanasPagadas: 'Gestionar campanas pagadas',
    gestionarPresupuestoPublicitario: 'Gestionar presupuesto publicitario',
    gestionarRed: 'Gestionar red B2B',
    gestionarMenus: 'Gestionar menus QR',
    gestionarEmpleados: 'Gestionar empleados',
    editarNegocio: 'Editar ficha del negocio',
    gestionarEmpleos: 'Publicar empleos',
  };

  static Map<String, bool> defaultsForCargo(String cargo) {
    final normalized = cargo.trim().toLowerCase();
    final base = <String, bool>{for (final key in all) key: false};

    base[verPanel] = true;
    base[gestionarPedidos] = true;
    base[escanearPedidos] = true;

    if (normalized.contains('cajer') ||
        normalized.contains('vendedor') ||
        normalized.contains('mostrador')) {
      base[pagosQr] = true;
      base[pagosAlias] = true;
      base[gestionarInventario] = true;
      return base;
    }

    if (normalized.contains('almacen') ||
        normalized.contains('inventario') ||
        normalized.contains('bodega')) {
      base[gestionarInventario] = true;
      base[crearProductos] = true;
      base[editarProductos] = true;
      return base;
    }

    if (normalized.contains('delivery') ||
        normalized.contains('repartidor') ||
        normalized.contains('mensajer')) {
      base[gestionarDelivery] = true;
      base[escanearPedidos] = true;
      return base;
    }

    if (normalized.contains('gerente') ||
        normalized.contains('supervisor') ||
        normalized.contains('admin')) {
      for (final key in all) {
        base[key] = key != gestionarEmpleados;
      }
      return base;
    }

    return base;
  }

  static Map<String, bool> normalize(Map<String, dynamic>? raw) {
    final result = <String, bool>{for (final key in all) key: false};
    if (raw == null) return result;
    for (final key in all) {
      final value = raw[key];
      result[key] = value == true || value == 1 || value == 'true';
    }
    return result;
  }

  static bool allows(Map<String, bool> permissions, String key) {
    return permissions[key] == true;
  }
}
