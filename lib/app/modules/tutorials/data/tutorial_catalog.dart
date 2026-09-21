import 'package:flutter/material.dart';

import '../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../domain/models/tutorial_definition.dart';

class TutorialCatalog {
  const TutorialCatalog._();

  static const List<TutorialDefinition> _all = [
    // ============================================================
    //  TRANSVERSALES (aplica a todos los roles)
    // ============================================================
    TutorialDefinition(
      id: 'comun_perfil',
      titulo: 'Conoce tu perfil',
      descripcion:
          'Todo lo que puedes hacer desde tu perfil: billetera, tickets, '
          'preferencias y el estado de tu APK.',
      icono: Icons.person_outline_rounded,
      rutas: ['/profile'],
      pasos: [
        TutorialStep(
          titulo: 'Tu identidad',
          descripcion:
              'En la cabecera ves tu correo y el rol activo. Si tienes varios '
              'modos (cliente, negocio, delivery) puedes cambiar entre ellos '
              'con el interruptor de modo.',
          icono: Icons.person_rounded,
        ),
        TutorialStep(
          titulo: 'Billetera y notificaciones',
          descripcion:
              'Desde los accesos rapidos consultas tu saldo ConKkao, haces '
              'transferencias por alias o QR y revisas avisos de pedidos, '
              'promociones y del sistema.',
          icono: Icons.account_balance_wallet_outlined,
        ),
        TutorialStep(
          titulo: 'Tickets de soporte',
          descripcion:
              'Si algo falla, abre un ticket desde "Tickets de soporte". '
              'Adjunta una captura y sigue el estado hasta que se atienda.',
          icono: Icons.support_agent_rounded,
        ),
        TutorialStep(
          titulo: 'Actualizaciones',
          descripcion:
              'La tarjeta "Aplicacion" muestra la version instalada y avisa '
              'cuando haya una APK nueva disponible para descargar.',
          icono: Icons.system_update_outlined,
        ),
        TutorialStep(
          titulo: 'Preferencias y sesion',
          descripcion:
              'Tu tema, categorias favoritas y privacidad se ajustan en '
              '"Preferencias". Recuerda cerrar sesion si compartes el equipo.',
          icono: Icons.settings_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'comun_buscar',
      titulo: 'Explora la vitrina',
      descripcion:
          'Encuentra negocios, productos y servicios usando la barra de '
          'busqueda y las tarjetas de la pantalla de inicio.',
      icono: Icons.storefront_outlined,
      rutas: ['/home', '/search'],
      pasos: [
        TutorialStep(
          titulo: 'Pantalla de inicio',
          descripcion:
              'El inicio agrupa recomendados, negocios cercanos y ofertas. '
              'Desplazate para descubrir mas contenido.',
          icono: Icons.home_outlined,
        ),
        TutorialStep(
          titulo: 'Busqueda',
          descripcion:
              'Usa la barra de busqueda para filtrar por producto, negocio o '
              'rubro. Los resultados se actualizan mientras escribes.',
          icono: Icons.search_rounded,
        ),
        TutorialStep(
          titulo: 'Detalles',
          descripcion:
              'Entra a un producto o negocio para ver precios, horarios, '
              'resenas y la forma de pedir o visitar.',
          icono: Icons.visibility_outlined,
        ),
        TutorialStep(
          titulo: 'Favoritos',
          descripcion:
              'Marca con el corazon lo que te guste y lo tendras a mano desde '
              'la seccion Favoritos de tu perfil.',
          icono: Icons.favorite_border_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'comun_favoritos',
      titulo: 'Guardar favoritos',
      descripcion:
          'Acumula productos, negocios, servicios y repartidores que quieras '
          'volver a consultar.',
      icono: Icons.favorite_border_rounded,
      rutas: ['/favorites'],
      pasos: [
        TutorialStep(
          titulo: 'Que puedes guardar',
          descripcion:
              'Aqui aparecen los productos, negocios y servicios que marcaste '
              'como favoritos mientras explorabas.',
          icono: Icons.heart_broken_outlined,
        ),
        TutorialStep(
          titulo: 'Comprar desde favoritos',
          descripcion:
              'Toca un favorito para abrir su detalle y agregarlo al carrito '
              'sin volver a buscarlo.',
          icono: Icons.shopping_cart_outlined,
        ),
        TutorialStep(
          titulo: 'Quitar favoritos',
          descripcion:
              'Usa el icono en cada tarjeta para dejar de seguirlo cuando '
              'quieras.',
          icono: Icons.remove_circle_outline_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'comun_billetera',
      titulo: 'Billetera ConKkao',
      descripcion:
          'Consulta tu saldo, envia y recibe dinero por alias o codigo QR y '
          'revisa tus movimientos.',
      icono: Icons.account_balance_wallet_outlined,
      rutas: ['/creditos', '/billetera'],
      pasos: [
        TutorialStep(
          titulo: 'Tu saldo',
          descripcion:
              'El saldo ConKkao se usa para pagar dentro de la plataforma. '
              'La tarjeta superior muestra el total disponible.',
          icono: Icons.account_balance_wallet_outlined,
        ),
        TutorialStep(
          titulo: 'Transferencias',
          descripcion:
              'Envía y recibe entre usuarios de la plataforma por tu alias o '
              'escaneando un codigo QR.',
          icono: Icons.qr_code_scanner_rounded,
        ),
        TutorialStep(
          titulo: 'Movimientos',
          descripcion:
              'El historial detalla cada entrada y salida: pagos, recargas, '
              'devoluciones y transferencias.',
          icono: Icons.receipt_long_outlined,
        ),
        TutorialStep(
          titulo: 'Agregar saldo',
          descripcion:
              'Desde esta vista puedes comprar creditos o vincular un metodo '
              'de pago para recargar tu billetera.',
          icono: Icons.add_card_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'comun_notificaciones',
      titulo: 'Centro de notificaciones',
      descripcion:
          'Todos los avisos de pedidos, promociones, pagos y del sistema en '
          'un solo lugar.',
      icono: Icons.notifications_none_rounded,
      rutas: ['/notifications'],
      pasos: [
        TutorialStep(
          titulo: 'Tipos de aviso',
          descripcion:
              'Noticias de tus pedidos, nuevas promociones, movimientos de '
              'billetera y mensajes del sistema llegan a esta pantalla.',
          icono: Icons.notifications_active_outlined,
        ),
        TutorialStep(
          titulo: 'Marca como leidas',
          descripcion:
              'Toca una notificacion para abrir lo que avisa; las que ya '
              'revisaste se distinguen visualmente.',
          icono: Icons.done_all_rounded,
        ),
        TutorialStep(
          titulo: 'Permisos del telefono',
          descripcion:
              'Si no te llegan avisos, activa las notificaciones de ConKkao '
              'en los ajustes del dispositivo.',
          icono: Icons.notifications_off_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'comun_tickets',
      titulo: 'Tickets de soporte',
      descripcion:
          'Reporta cualquier problema con una captura y sigue el estado de tu '
          'solicitud hasta que te atiendan.',
      icono: Icons.support_agent_rounded,
      rutas: ['/soporte/tickets'],
      pasos: [
        TutorialStep(
          titulo: 'Crea un ticket',
          descripcion:
              'Describe el problema con un titulo y una explicacion clara '
              'para que te entendamos mas rapido.',
          icono: Icons.edit_note_rounded,
        ),
        TutorialStep(
          titulo: 'Adjunta una captura',
          descripcion:
              'Sube una imagen como evidencia: ayudara al equipo a '
              'identificar la falla.',
          icono: Icons.add_photo_alternate_outlined,
        ),
        TutorialStep(
          titulo: 'Sigue el estado',
          descripcion:
              'El estado pasa de pendiente a resuelto o cancelado. Cuando se '
              'atienda veras la resolucion escrita por soporte.',
          icono: Icons.manage_search_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'comun_carro',
      titulo: 'Finalizar un pedido',
      descripcion:
          'Revisa tu carrito, elige como recibir el pedido y confirma de '
          'forma segura.',
      icono: Icons.shopping_cart_outlined,
      rutas: ['/cart'],
      pasos: [
        TutorialStep(
          titulo: 'Resumen del pedido',
          descripcion:
              'Aqui ves los productos, cantidades y el total a pagar antes de '
              'confirmar.',
          icono: Icons.receipt_long_outlined,
        ),
        TutorialStep(
          titulo: 'Forma de entrega',
          descripcion:
              'Elige entre recogida en el local o entrega por un repartidor '
              'disponible cerca de ti.',
          icono: Icons.delivery_dining_outlined,
        ),
        TutorialStep(
          titulo: 'Pago y confirmacion',
          descripcion:
              'Confirma el pedido con tu medio de pago y recibiras el aviso '
              'cuando este listo o en camino.',
          icono: Icons.verified_outlined,
        ),
      ],
    ),

    // ============================================================
    //  CLIENTE
    // ============================================================
    TutorialDefinition(
      id: 'cliente_mis_pedidos',
      titulo: 'Mis pedidos',
      descripcion:
          'Consulta el estado de tus reservas, compras y entregas solicitadas '
          'desde el inicio del carrito.',
      icono: Icons.receipt_long_outlined,
      modo: RoleMode.client,
      rutas: ['/orders'],
      pasos: [
        TutorialStep(
          titulo: 'Lista de pedidos',
          descripcion:
              'Aparecen tus pedidos recientes con su estado: pendiente, '
              'confirmado, en camino o completado.',
          icono: Icons.list_alt_rounded,
        ),
        TutorialStep(
          titulo: 'Detalle del pedido',
          descripcion:
              'Toca un pedido para ver sus productos, el negocio, la '
              'direccion y el repartidor asignado.',
          icono: Icons.details_rounded,
        ),
        TutorialStep(
          titulo: 'Acciones',
          descripcion:
              'Mientras el pedido este pendiente puedes cancelarlo o abrir '
              'un ticket de soporte si algo sale mal.',
          icono: Icons.more_horiz_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'cliente_escaner',
      titulo: 'Escana productos y QR',
      descripcion:
          'Usa la camara para consultar productos, codigos y contenido del '
          'negocio al instante.',
      icono: Icons.qr_code_scanner_rounded,
      modo: RoleMode.client,
      rutas: ['/scanner', '/scan-history'],
      pasos: [
        TutorialStep(
          titulo: 'Apunta y escanea',
          descripcion:
              'Enfoca un codigo QR o de barra dentro del recuadro para '
              'obtener el resultado.',
          icono: Icons.qr_code_scanner_rounded,
        ),
        TutorialStep(
          titulo: 'Que puedes consultar',
          descripcion:
              'Dependiendo del codigo veras productos, negocios, servicios '
              'o alias de billetera.',
          icono: Icons.auto_awesome_outlined,
        ),
        TutorialStep(
          titulo: 'Historial de escaneos',
          descripcion:
              'Cada consulta queda guardada para que puedas volver a ella '
              'desde tu historial.',
          icono: Icons.history_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'cliente_resenas',
      titulo: 'Mis resenas',
      descripcion:
          'Escribe y administra las opiniones que publicas despues de tus '
          'compras.',
      icono: Icons.rate_review_outlined,
      modo: RoleMode.client,
      rutas: ['/my-reviews'],
      pasos: [
        TutorialStep(
          titulo: 'Donde aparecen',
          descripcion:
              'Tus opiniones y calificaciones de negocios y productos se '
              'listan aqui, visibles para otros usuarios.',
          icono: Icons.rate_review_outlined,
        ),
        TutorialStep(
          titulo: 'Edita tu opinion',
          descripcion:
              'Puedes corregir la calificacion o el texto de tus resenas '
              'en cualquier momento.',
          icono: Icons.edit_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'cliente_gamificacion',
      titulo: 'Puntos y nivel',
      descripcion:
          'Gana puntos con tu actividad, sube de nivel y participa en '
          'sorteos y cashback.',
      icono: Icons.workspace_premium_outlined,
      modo: RoleMode.client,
      rutas: ['/gamification'],
      pasos: [
        TutorialStep(
          titulo: 'Tu nivel',
          descripcion:
              'La tarjeta principal muestra tus puntos, nivel actual y el '
              'progreso al siguiente.',
          icono: Icons.military_tech_outlined,
        ),
        TutorialStep(
          titulo: 'Como sumar puntos',
          descripcion:
              'Comprar, escanear, dejar resenas y usar tus favoritos suman '
              'puntos bonus.',
          icono: Icons.bolt_outlined,
        ),
        TutorialStep(
          titulo: 'Sorteos y cashback',
          descripcion:
              'Consulta las promociones activas donde puedes canjear tus '
              'puntos por beneficios.',
          icono: Icons.card_giftcard_outlined,
        ),
      ],
    ),

    // ============================================================
    //  NEGOCIO
    // ============================================================
    TutorialDefinition(
      id: 'negocio_dashboard',
      titulo: 'Dashboard del negocio',
      descripcion:
          'Resumen de ventas, reservas, inventario y rendimiento de tus '
          'negocios en una sola vista.',
      icono: Icons.dashboard_customize_outlined,
      modo: RoleMode.business,
      rutas: ['/business/dashboard'],
      pasos: [
        TutorialStep(
          titulo: 'Indicadores',
          descripcion:
              'La parte superior resume ventas, pedidos activos y '
              'rendimiento del periodo reciente.',
          icono: Icons.insights_rounded,
        ),
        TutorialStep(
          titulo: 'Accesos rapidos',
          descripcion:
              'Desde aqui navegas al inventario, pedidos recibidos, '
              'promociones y publicaciones.',
          icono: Icons.launch_rounded,
        ),
        TutorialStep(
          titulo: 'Cambiar de negocio',
          descripcion:
              'Si administras varios negocios, cambia el activo desde el '
              'selector para ver sus datos.',
          icono: Icons.swap_horiz_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'negocio_inventario',
      titulo: 'Inventario y productos',
      descripcion:
          'Crea productos, controla el stock, los precios y la visibilidad '
          'en la vitrina.',
      icono: Icons.inventory_2_outlined,
      modo: RoleMode.business,
      rutas: ['/business/inventory'],
      pasos: [
        TutorialStep(
          titulo: 'Crea un producto',
          descripcion:
              'Agrega nombre, descripcion, precio y categorias para que '
              'aparezca en tu vitrina.',
          icono: Icons.add_box_outlined,
        ),
        TutorialStep(
          titulo: 'Stock y disponibilidad',
          descripcion:
              'Actualiza las cantidades y marca si el producto esta '
              'disponible, agotado u oculto.',
          icono: Icons.inventory_rounded,
        ),
        TutorialStep(
          titulo: 'Busca y filtra',
          descripcion:
              'Usa el buscador y los filtros para ubicar rapido un producto '
              'entre todo tu catalogo.',
          icono: Icons.manage_search_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'negocio_pedidos',
      titulo: 'Pedidos recibidos',
      descripcion:
          'Administra las reservas, ventas y entregas que llegan de tus '
          'clientes.',
      icono: Icons.receipt_long_outlined,
      modo: RoleMode.business,
      rutas: ['/business/orders', '/business/my-orders'],
      pasos: [
        TutorialStep(
          titulo: 'Nuevos pedidos',
          descripcion:
              'Los pedidos entrantes aparecen primero. Revisa productos y '
              'datos del cliente antes de confirmar.',
          icono: Icons.notifications_active_outlined,
        ),
        TutorialStep(
          titulo: 'Estados',
          descripcion:
              'Avanza cada pedido de confirmado a preparado y despues a '
              'entregado o tus propios estados de despacho.',
          icono: Icons.timeline_rounded,
        ),
        TutorialStep(
          titulo: 'Servicio de entrega',
          descripcion:
              'Si el cliente pidio envio, veras el repartidor asignado y '
              'tendras el seguimiento de la ruta.',
          icono: Icons.map_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'negocio_equipo',
      titulo: 'Equipo y permisos',
      descripcion:
          'Invita colaboradores a tu negocio y asigna cargos y permisos de '
          'forma segura.',
      icono: Icons.groups_outlined,
      modo: RoleMode.business,
      rutas: ['/business/team'],
      pasos: [
        TutorialStep(
          titulo: 'Invita alguien',
          descripcion:
              'Genera una invitacion con el correo de la persona que se '
              'hara cargo de funciones del negocio.',
          icono: Icons.person_add_alt_rounded,
        ),
        TutorialStep(
          titulo: 'Cargos y permisos',
          descripcion:
              'Define si el invitado puede ver pedidos, editar inventario, '
              'publicar o solo consultar.',
          icono: Icons.manage_accounts_outlined,
        ),
        TutorialStep(
          titulo: 'Estado de los miembros',
          descripcion:
              'El listado muestra quien ya se unio y quien sigue a la '
              'espera de aceptar la invitacion.',
          icono: Icons.group_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'negocio_promociones',
      titulo: 'Promociones',
      descripcion:
          'Crea ofertas y descuentos que se muestran en la vitrina para '
          'atraer mas clientes.',
      icono: Icons.campaign_outlined,
      modo: RoleMode.business,
      rutas: ['/business/promotions'],
      pasos: [
        TutorialStep(
          titulo: 'Crea una promocion',
          descripcion:
              'Define el tipo de oferta, el descuento y el rango de vigencia '
              'para publicarla.',
          icono: Icons.add_circle_outline_rounded,
        ),
        TutorialStep(
          titulo: 'Aplica sobre el catalogo',
          descripcion:
              'Selecciona los productos o servicios que entran en la '
              'promocion.',
          icono: Icons.local_offer_outlined,
        ),
        TutorialStep(
          titulo: 'Seguimiento',
          descripcion:
              'Consulta cuantas veces se ha canjeado y activala o '
              'desactivarla cuando quieras.',
          icono: Icons.analytics_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'negocio_publicaciones',
      titulo: 'Mis publicaciones',
      descripcion:
          'Crea y gestiona anuncios sobre tus productos y novedades en '
          'la vitrina.',
      icono: Icons.post_add_outlined,
      modo: RoleMode.business,
      rutas: ['/business/posts'],
      pasos: [
        TutorialStep(
          titulo: 'Nueva publicacion',
          descripcion:
              'Escribe la novedad de tu negocio con fotos para destacarla '
              'en la vitrina.',
          icono: Icons.post_add_outlined,
        ),
        TutorialStep(
          titulo: 'Estado y alcance',
          descripcion:
              'Sigue cuantas vistas tiene y edita o retira la publicacion '
              'cuando termine su ciclo.',
          icono: Icons.visibility_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'negocio_configuracion',
      titulo: 'Configuracion del negocio',
      descripcion:
          'Tu marca, horarios, ubicacion, delivery y la apariencia de tu '
          'perfil de negocio.',
      icono: Icons.storefront_outlined,
      modo: RoleMode.business,
      rutas: ['/business/settings', '/business/store'],
      pasos: [
        TutorialStep(
          titulo: 'Ficha del negocio',
          descripcion:
              'Actualiza el nombre, la descripcion, la categoria y el logo '
              'que ven tus clientes.',
          icono: Icons.storefront_outlined,
        ),
        TutorialStep(
          titulo: 'Horarios y ubicacion',
          descripcion:
              'Indica cuando abres y en que zona operas para que los '
              'clientes sepan si puedes atenderlos.',
          icono: Icons.schedule_rounded,
        ),
        TutorialStep(
          titulo: 'Delivery',
          descripcion:
              'Configura si el negocio reparte, con que tarifa y hasta que '
              'distancia.',
          icono: Icons.delivery_dining_outlined,
        ),
        TutorialStep(
          titulo: 'Plan y apariencia',
          descripcion:
              'Consulta tu plan activo y personaliza la presentacion de tu '
              'negocio en la plataforma.',
          icono: Icons.workspace_premium_outlined,
        ),
      ],
    ),

    // ============================================================
    //  DELIVERY
    // ============================================================
    TutorialDefinition(
      id: 'delivery_panel',
      titulo: 'Panel delivery',
      descripcion:
          'Tu centro de operaciones: solicitudes, entregas activas, ingresos '
          'y reputacion.',
      icono: Icons.delivery_dining_outlined,
      modo: RoleMode.delivery,
      rutas: ['/delivery/dashboard'],
      pasos: [
        TutorialStep(
          titulo: 'Vista general',
          descripcion:
              'El panel resume las solicitudes disponibles, tus entregas en '
              'curso, los ingresos y tu reputacion.',
          icono: Icons.dashboard_outlined,
        ),
        TutorialStep(
          titulo: 'Activa tu perfil',
          descripcion:
              'Para recibir solicitudes ponte disponible desde tu perfil '
              'delivery (zona, vehiculo y horario).',
          icono: Icons.toggle_on_outlined,
        ),
        TutorialStep(
          titulo: 'Mantente informado',
          descripcion:
              'Acepta solicitudes desde la seccion "Solicitudes" y sigue '
              'cada entrega desde "Ruta y mapa".',
          icono: Icons.tips_and_updates_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'delivery_solicitudes',
      titulo: 'Solicitudes',
      descripcion:
          'Elige las entregas disponibles que encajen con tu ubicacion y '
          'tarifa.',
      icono: Icons.assignment_outlined,
      modo: RoleMode.delivery,
      rutas: ['/delivery/requests'],
      pasos: [
        TutorialStep(
          titulo: 'Entregas disponibles',
          descripcion:
              'La lista muestra pedidos cercanos con origen, destino, '
              'distancia y la tarifa de envio.',
          icono: Icons.assignment_outlined,
        ),
        TutorialStep(
          titulo: 'Acepta una entrega',
          descripcion:
              'Toca la solicitud que te convenga y confirmala; se movera a '
              'tus entregas activas.',
          icono: Icons.check_circle_outline_rounded,
        ),
        TutorialStep(
          titulo: 'Rechaza sin penalizar',
          descripcion:
              'Si no te conviene, puedes ignorarla: la solicitud quedara '
              'para otro repartidor.',
          icono: Icons.close_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'delivery_ruta',
      titulo: 'Ruta y mapa',
      descripcion:
          'Mapa en tiempo real de tus entregas, con tu ubicacion y el '
          'camino hacia cada cliente.',
      icono: Icons.map_outlined,
      modo: RoleMode.delivery,
      rutas: ['/delivery/route'],
      pasos: [
        TutorialStep(
          titulo: 'Tu marcador',
          descripcion:
              'Tu posicion aparece con un marcador marcado en el mapa para '
              'que te ubiques siempre.',
          icono: Icons.near_me_rounded,
        ),
        TutorialStep(
          titulo: 'Buscador y ubicacion',
          descripcion:
              'Usa el buscador para mover el mapa hasta una direccion y el '
              'boton de ubicacion para volver a tu posicion.',
          icono: Icons.search_rounded,
        ),
        TutorialStep(
          titulo: 'Entrega en curso',
          descripcion:
              'Selecciona la entrega activa para trazar la ruta hasta el '
              'cliente y marcar la entrega al llegar.',
          icono: Icons.flag_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'delivery_historial',
      titulo: 'Historial de entregas',
      descripcion:
          'Repasa las entregas completadas, los kilometros recorridos y tus '
          'pagos.',
      icono: Icons.history_rounded,
      modo: RoleMode.delivery,
      rutas: ['/delivery/history'],
      pasos: [
        TutorialStep(
          titulo: 'Entregas completadas',
          descripcion:
              'La lista muestra cada entrega terminada con su detalle y '
              'resultado.',
          icono: Icons.history_rounded,
        ),
        TutorialStep(
          titulo: 'Kilometros y pagos',
          descripcion:
              'Consulta el acumulado de kilometros y los pagos generados '
              'por tus entregas.',
          icono: Icons.trending_up_rounded,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'delivery_perfil',
      titulo: 'Perfil delivery',
      descripcion: 'Tu vehiculo, tarifa, disponibilidad y zona de trabajo.',
      icono: Icons.badge_outlined,
      modo: RoleMode.delivery,
      rutas: ['/delivery/profile'],
      pasos: [
        TutorialStep(
          titulo: 'Tus datos',
          descripcion:
              'Configura tu vehiculo, tipo de transporte y tarifa de '
              'entrega.',
          icono: Icons.bike_scooter_rounded,
        ),
        TutorialStep(
          titulo: 'Disponibilidad',
          descripcion:
              'Activa o desactiva que quieres recibir solicitudes nuevas en el '
              'momento.',
          icono: Icons.toggle_on_outlined,
        ),
        TutorialStep(
          titulo: 'Zona de trabajo',
          descripcion:
              'Define la zona donde prefieres operar para que las solicitudes '
              'lleguen segun tu ubicacion.',
          icono: Icons.location_on_outlined,
        ),
      ],
    ),
    TutorialDefinition(
      id: 'delivery_cerca',
      titulo: 'Repartidores cerca',
      descripcion:
          'Sincroniza tu marcador y ve quién esta trabajando cerca de ti '
          'en el mapa.',
      icono: Icons.location_on_outlined,
      modo: RoleMode.delivery,
      rutas: ['/delivery/nearby'],
      pasos: [
        TutorialStep(
          titulo: 'Mapa de repartidores',
          descripcion:
              'El mapa muestra a los repartidores activos alrededor de tu '
              'posicion.',
          icono: Icons.maps_home_work_outlined,
        ),
        TutorialStep(
          titulo: 'Tu marcador',
          descripcion:
              'Tu posicion se marca en el mapa y se actualiza mientras te '
              'mueves.',
          icono: Icons.near_me_rounded,
        ),
        TutorialStep(
          titulo: 'Navegacion del mapa',
          descripcion:
              'Usa el buscador o el boton de ubicacion para desplazarte por el '
              'mapa con facilidad.',
          icono: Icons.explore_outlined,
        ),
      ],
    ),
  ];

  static List<TutorialDefinition> get all => List.unmodifiable(_all);

  static List<TutorialDefinition> forMode(RoleMode modo) {
    return _all
        .where((t) => t.esTransversal || t.modo == modo)
        .toList(growable: false);
  }

  static List<TutorialDefinition> roleScopedForMode(RoleMode modo) {
    return _all.where((t) => t.modo == modo).toList(growable: false);
  }

  static List<TutorialDefinition> transversal() {
    return _all.where((t) => t.esTransversal).toList(growable: false);
  }

  static List<TutorialDefinition> forLocation(String location) {
    return _all
        .where((t) => t.matchesLocation(location))
        .toList(growable: false);
  }

  static TutorialDefinition? byId(String id) {
    for (final tutorial in _all) {
      if (tutorial.id == id) return tutorial;
    }
    return null;
  }
}
