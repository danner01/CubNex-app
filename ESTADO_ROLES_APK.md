# Estado general de la APK por rol (hecho vs pendiente)

Fecha: 2026-07-17

## Documentacion revisada

- `MEGAMARKET-APK/README.md`
- `MEGAMARKET-APK/ARCHITECTURE.md`
- `SUPERADMIN/docs/APP_FLUTTER.md`
- `SUPERADMIN/docs/ESTADO_APIS_PANEL.md`
- `MEGAMARKET-APK/lib/app/config/routes/app_routes.dart`
- `MEGAMARKET-APK/lib/app/config/routes/app_router.dart`
- Avances recientes de la sesion (reservas/caducidad, APK release, notificaciones).

---

## Resumen ejecutivo

- La APK ya esta operativa con arquitectura modular (`config/common/modules`) y flujo por modos.
- El backend y panel (SUPERADMIN) tienen base estable y APIs validadas para integracion movil.
- En esta etapa, lo mas avanzado esta en **cliente** y **negocio** (pedidos, reservas, red, promociones, notificaciones).
- **Delivery** ya tiene hub y flujo de estados, pero aun requiere cierre funcional de operaciones de ruta/cobro/evidencia.
- Distribucion APK mejorada a `split-per-abi` para bajar peso de descarga.

---

## Avances ya implementados (global)

1. **Caducidad de reservas (Fase 1 y 2)**
   - Configuracion por negocio (`reserva_minutos_default`).
   - Override por pedido al cambiar estado.
   - Countdown visible en cliente y negocio.
   - Auto-marcado de pedidos vencidos a `caducado`.
   - Aviso push cuando falta <= 1h.
   - Alerta sonora en foreground.

2. **UX de tiempo de reserva**
   - Input + selector de unidad (minutos/horas/dias) en ajustes y flujo de pedidos.
   - Etiqueta amigable en contador (`X horas/dias restantes`).

3. **Notificaciones**
   - Campana con conteo de no leidas.
   - Refresco en tiempo real al recibir push y al marcar como leidas.
   - Pantalla de notificaciones con filtro y acciones de lectura.

4. **Negocio / B2B**
   - Red de negocios con solicitudes pendientes/aceptacion/rechazo y control de duplicados.
   - Pedidos de negocio robustecidos.

5. **Actualizaciones APK**
   - Comparacion correcta por version semantica + build number.
   - Pipeline release con APK por ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
   - Integracion con Blob/Vercel y landing de descarga.

---

## Estado por rol

## 1) Invitado

### Hecho
- Puede navegar home/busqueda/mapa/detalle de negocio-producto sin login.
- Flujo onboarding/login enrutable y estable.

### Pendiente
- Endurecer experiencia guest->registro con CTAs contextuales mas agresivos.
- Revisar paridad completa de contenidos guest (algunas acciones siguen mostrando bloqueo tardio).

---

## 2) Cliente

### Hecho
- Home, busqueda, detalle de negocio/producto, carrito, pedidos.
- Notificaciones internas + campana + marcar leidas.
- Gamificacion/promociones/favoritos/perfil/preferencias.
- Seguimiento de pedidos con estados y countdown de reserva cuando aplica.

### Pendiente
- QA E2E completo de flujo compra->entrega->confirmacion en datos reales.
- Pulir resiliencia offline/intermitencia en pantallas de alto trafico.
- Cerrar matrix de pruebas de push en foreground/background/terminated.

---

## 3) Negocio

### Hecho
- Dashboard, inventario, vista tienda, ajustes, wizard.
- Gestion de pedidos del negocio y pedidos propios como solicitante.
- Ajuste de caducidad de reserva por pedido.
- Red B2B operativa (solicitudes/estados).
- Promociones, menus, propiedades, transporte y empleos en rutas dedicadas.

### Pendiente
- Completar formularios "reales" y cobertura funcional profunda de cada vertical (segun `README.md`).
- Validar punta a punta reportes/metricas con datos productivos.
- Endurecer politicas de permisos por rol en todos los endpoints de gestion.

---

## 4) Delivery

### Hecho
- Hub de delivery con secciones: dashboard, solicitudes, ruta, historial, perfil.
- Lectura/filtrado de pedidos de delivery por estado y fechas.
- Flujo de refresco y manejo basico de estado de pedidos delivery.

### Pendiente
- Cerrar operacion de ruta en tiempo real (tracking/logistica completa).
- Evidencias de entrega/cobro y validaciones de cierre.
- KPIs y tableros de productividad delivery mas completos.

---

## 5) Dependencias de release/publicacion (transversal)

Segun documentacion de APK, aun falta antes de publicar en tiendas:

- Iconos/splash finales.
- `google-services.json` (Android) y `GoogleService-Info.plist` (iOS).
- Firma release (keystore Android + firma iOS).
- Revisar `firebase_options.dart` con configuracion final de Firebase.

---

## Plan ejecutable por sprints (checklist)

## Sprint 1 - Estabilidad y tiempo real (1 semana)

### Cliente
- [ ] Ejecutar QA E2E completo de flujo compra -> entrega -> confirmacion.
- [ ] Validar push en foreground/background/terminated en Android real.
- [ ] Validar estado de campana y notificaciones en cambios de sesion (guest/login/logout).

### Negocio
- [ ] Probar pedidos con caducidad en todos los cambios de estado clave.
- [ ] Verificar consistencia dashboard vs pedidos reales vs notificaciones enviadas.
- [ ] Revisar errores de red intermitente en panel de pedidos y red B2B.

### Delivery
- [ ] Validar filtros por estado/fecha sobre volumen real de pedidos.
- [ ] Confirmar refresco correcto al volver de scanner y al reabrir app.
- [ ] Revisar estados finales (recibido/completado/cancelado) sin inconsistencias.

### Transversal
- [ ] Congelar una baseline de regression manual por rol.
- [ ] Documentar bugs abiertos con evidencia y prioridad.

---

## Sprint 2 - Cierre funcional Delivery + endurecimiento negocio (1-2 semanas)

### Delivery
- [ ] Completar flujo operativo de ruta (asignacion -> recogida -> entrega -> cierre).
- [ ] Agregar evidencia de entrega/cobro (si aplica en backend y UX).
- [ ] Incorporar KPIs de productividad (entregas, tiempos, cancelaciones).

### Negocio
- [ ] Completar formularios "reales" pendientes (inventario/wizard/tienda).
- [ ] Endurecer permisos por rol en endpoints de gestion.
- [ ] Validar punta a punta reportes/metricas con datos de prueba productivos.

### Cliente
- [ ] Revisar experiencias guest->registro y CTAs de conversion.
- [ ] Afinar resiliencia en escenarios offline/intermitentes.

---

## Sprint 3 - Release store-ready (1 semana)

### Publicacion
- [ ] Integrar iconos y splash finales.
- [ ] Configurar `android/app/google-services.json`.
- [ ] Configurar `ios/Runner/GoogleService-Info.plist`.
- [ ] Configurar firma release Android (keystore) e iOS (certificados/perfiles).
- [ ] Revisar y regenerar `firebase_options.dart` con apps finales.

### Distribucion APK
- [ ] Verificar release `split-per-abi` en CI.
- [ ] Confirmar landing y `/api/apk/latest` con URLs ABI correctas.
- [ ] Ejecutar smoke test de descarga e instalacion por arquitectura.

### Go/No-Go
- [ ] Cerrar checklist de regression final por rol.
- [ ] Aprobacion funcional cliente/negocio/delivery.
- [ ] Registrar version final + changelog + artefactos.

---

## Backlog de mejora continua (post-release)

- [ ] Mejoras de UX en onboarding y activacion.
- [ ] Observabilidad de notificaciones y entrega push.
- [ ] Automatizar mas pruebas E2E por rol en CI.
