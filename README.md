# CubNex APK

Base Flutter para Android e iOS del SaaS CubNex.

## Arquitectura

- `lib/app/config`: entorno, HTTP, inyeccion, rutas y tema.
- `lib/app/common`: estado de sesion, entidades compartidas y widgets base.
- `lib/app/modules`: modulos por dominio con capas `data`, `domain`, `presentation` y `blocs`.
- Estado con `bloc` y `cubit`.
- Navegacion con `go_router`.
- Backend REST: `SUPERADMIN` expuesto en `/api/v1`.
- Backend publico actual: `https://supermarket-superadmin-rfz6.vercel.app/api/v1`.

## Configuracion local

Ejecuta dependencias:

```bash
flutter pub get
```

Por defecto la app apunta al backend desplegado en Vercel:

```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=TU_TOKEN
```

Android emulador contra backend local:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=MAPBOX_ACCESS_TOKEN=TU_TOKEN
```

Dispositivo fisico:

```bash
flutter run --dart-define=API_BASE_URL=http://IP_DE_TU_PC:3000 --dart-define=MAPBOX_ACCESS_TOKEN=TU_TOKEN
```

Produccion:

```bash
flutter build apk --release --dart-define=MAPBOX_ACCESS_TOKEN=TU_TOKEN
flutter build ios --release --dart-define=MAPBOX_ACCESS_TOKEN=TU_TOKEN
```

## Pendientes antes de publicar tiendas

- Sustituir iconos y splash por assets finales.
- Agregar `android/app/google-services.json`.
- Agregar `ios/Runner/GoogleService-Info.plist` y configurar firma en Xcode.
- Revisar `firebase_options.dart` con `flutterfire configure` cuando existan apps Android/iOS finales en Firebase.
- Crear keystore release Android y configurar firma.
- Completar formularios reales de inventario, wizard, tienda, busqueda y mapas usando los endpoints Swagger.
