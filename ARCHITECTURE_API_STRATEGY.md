# Estrategia de APIs y acceso a datos para CubNex

## Resultado del test

Backend probado: `https://supermarket-superadmin.vercel.app/api/v1`

Endpoints publicos probados:

- `/banners?limit=3`
- `/negocios?limit=3`
- `/productos/destacados?limit=3`
- `/busqueda/mapa?limit=3`
- `/tipos-negocio`
- `/suscripciones/planes?limit=3`

Resultado: las APIs responden, pero algunas llamadas tienen latencia alta por cold start o consultas no cacheadas. Esto afecta directamente al Home de la APK.

## Recomendacion

No usar un ORM que conecte la APK directamente a Postgres. En mobile no conviene abrir conexion SQL directa a la base de datos.

Usar arquitectura hibrida:

1. `supabase_flutter` para lecturas rapidas y seguras desde la APK.
2. Row Level Security en todas las tablas expuestas.
3. Views/RPC optimizadas para Home, busqueda, mapas, productos y tiendas.
4. Backend Next.js para operaciones sensibles:
   - SuperAdmin.
   - IA/Gemini.
   - Firebase Admin/FCM.
   - QR.
   - acciones con service role.
   - validaciones complejas.
   - pagos/suscripciones.

## Que mover directo a Supabase desde Flutter

- Home publico: negocios, productos destacados, banners activos.
- Busqueda global y mapa.
- Tipos de negocio.
- Perfil del usuario autenticado.
- Favoritos y suscripciones simples.
- Realtime para notificaciones o cambios de pedidos.
- Storage para imagenes, siempre con politicas RLS.

## Que mantener en backend Next.js

- Login Google/Firebase si depende de verificacion server-side.
- Vision IA/Gemini.
- Envio FCM.
- Generacion QR si requiere storage/firmas.
- Moderacion, auditoria y logs.
- Reportes SuperAdmin.
- Operaciones que requieren `SUPABASE_SERVICE_ROLE_KEY`.

## ORM/cache local recomendado

- `supabase_flutter`: cliente principal remoto.
- `drift`: cache local/offline para Home, busqueda e inventario.
- `brick_offline_first_with_supabase`: opcion avanzada si se quiere sincronizacion offline-first completa.

Primera fase recomendada: `supabase_flutter` + cache simple con `drift` o Hive. Dejar Brick para una fase posterior porque agrega complejidad.

## Siguiente paso tecnico

Crear en Flutter una capa `SupabaseDataSource` paralela al `ApiClient` actual:

- `HomeSupabaseDataSource`
- `SearchSupabaseDataSource`
- `BusinessSupabaseDataSource`
- `ProductSupabaseDataSource`

Luego migrar el Home primero, porque es la vista que mas sufre la latencia.
