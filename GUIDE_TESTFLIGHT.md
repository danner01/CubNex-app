# Guia TestFlight — ConKkao (iOS)

Esta guia describe como publicar la app iOS de ConKkao en **TestFlight** para
que un grupo de beta-testers la pruebe antes de ir a la App Store.

> Requisito de hardware: hace falta un **Mac con macOS** y **Xcode**. Este
> proyecto se desarrolla en Windows (Android), por lo que este documento se
> entrega como guia ejecutable en un Mac. No se incluyen aqui los pasos de
> activacion de la cuenta de Apple Developer porque dependen de credenciales
> del dueno.

## 0. Prerequisitos

- Mac con macOS 13+ y Xcode 15+ instalado.
- Flutter instalado en el Mac (`flutter doctor -v` sin errores en iOS).
- Cuenta de **Apple Developer Program** ($99/anio).
- Acceso a github.com/danner01/CubNex-app (para clonar o descargar el codigo).
- [opcional] CocoaPods (`sudo gem install cocoapods`).

La configuracion iOS ya existe en el repositorio (`ios/`) y ya incluye:

- Bundle id: `com.cubnex.app`
- Nombre visible: `ConKkao`
- Permisos: camara, galeria (leer/guardar), ubicacion y microfono ya declarados
  en `ios/Runner/Info.plist`.

## 1. Preparar el Mac

```bash
# Clonar el repositorio
git clone https://github.com/danner01/CubNex-app.git
cd CubNex-app

# Instalar dependencias e inicializar iOS
flutter pub get
flutter precache --ios
cd ios
pod install          # corre cocoapods (solo la primera vez)
cd ..
```

## 2. Firmado (signing) en Xcode

1. Abrir el proyecto:

   ```bash
   open ios/Runner.xcworkspace
   ```

2. En Xcode, seleccionar el target **Runner** y luego el tab **Signing & Capabilities**.
3. Marcar **Automatically manage signing**.
4. En **Team**, elegir el team de Apple Developer de la cuenta.
5. Verificar que el **Bundle Identifier** sea `com.cubnex.app` (o el que hayas
   registrado; si usas otro, registralo primero como App ID en la consola de
   desarrollador).
6. En **Deployment Info**, dejar iPhone/iPad como este.

Si el App ID `com.cubnex.app` no esta registrado, crearlo antes:

1. Consola de Apple Developer → Certificates, Identifiers & Profiles →
   **Identifiers** → **+**.
2. Elegir **App IDs** → **App**.
3. Bundle ID: `com.cubnex.app` (exact), nombre: `ConKkao`.
4. Los servicios (Push, Sign in with Apple...) se pueden activar aqui o mas tarde.

## 3. Subir la version y el build number

La version y el numero de build se toman de `pubspec.yaml`
(`version: X.Y.Z+BB`). Para TestFlight, **incrementa el numero de build** en
cada subida:

```yaml
version: 0.1.49+60   # sube +60, +61, ... en cada nueva prueba
```

En iOS, `+BB` es el build number de tu app. Nunca reutilices un numero de build
que ya se subio a App Store Connect.

Para el nombre de version visible usa el mismo `X.Y.Z` de Android:
- `0.1.49+59` (Android/Supabase) y `0.1.49+60` (iOS TestFlight) son coherentes.

## 4. Compilar el .ipa

Desde la raiz del repo (en el Mac):

```bash
flutter clean
flutter pub get
flutter build ipa --release
```

El comando:

- Compila y firma automaticamente con el team configurado.
- Genera `build/ios/ipa/*.ipa` listo para subir.
- Si algo falla por codigos de barras o capacidades, revisa el paso 2.

Si quieres un archivo tipo App Store (para subir con Transporter), el .ipa
generado sirve igual.

## 5. Crear la app en App Store Connect

1. Entrar en https://appstoreconnect.apple.com.
2. **Mi app** → boton **+** → **Nueva app**.
3. Elegir plataforma **iOS**, nombre **ConKkao**, idioma principal, bundle id
   `com.cubnex.app` y SKU `com.cubnex.app`.
4. Crear.

## 6. Subir el build

Opcion A (recomendada) — **Transporter**:

1. Descargar Transporter desde la App Store (Mac).
2. Arrastrar `build/ios/ipa/ConKkao.ipa` (o el .ipa generado) a la ventana.
3. Pulsar Subir con la cuenta de Apple Developer.

Opcion B — Xcode Organizer:

1. En Xcode: Window → Organizer.
2. Con el paso 4 archivado, aparecera en Archives.
3. Seleccionar → **Distribute App** → **App Store Connect** → **Upload**.

Opcion C — Command Line (alternativa avanzada):

```bash
xcrun altool --upload-app \
  -f build/ios/ipa/*.ipa \
  -t ios \
  -u <apple-id> \
  -p <app-specific-password>   # genera una en appleid.apple.com
```

## 7. Activar el build en TestFlight

1. En App Store Connect → **ConKkao** → **TestFlight**.
2. Apartado **TESTERS INTERNOS**: anade a los miembros del team Apple que
   seran probadores con acceso interno (aparecen al subir el build).
3. Apartado **GRUPOS**:
   - Crear un grupo (ej. "Beta ConKkao").
   - Anadir testers por email (externos aceptan invitacion en su email; usan la
     app TestFlight).
   - Para **probar en externos (recomendado para publico sin cuenta Apple)**:
     activar "Public Link" y compartir el enlace publico de TestFlight.
4. En **Compilaciones / Builds**: esperar a que la compilacion termine de
  "procesarse" (puede tardar 10-60 min). Cuando este activa, click al build
   (con el `+60`, etc.), y:
   - En **Export Compliance**: la app no usa cifrado a medida (solo HTTPS), asi
     que se puede responder "No usa cifrado" o "Solo cubre lo que exime";
     generalmente se marca **No** y se guarda.
   - En **Test Information**: rellenar "Que hay de nuevo en esta version" (ej.
     "Escaneo de productos con IA + onboarding para nuevos usuarios").
   - Guardar.
5. Asignar el build al grupo: build → **+** junto al grupo, o en Grupos →
   anade build.
6. Los testers recibiran el aviso y podran descargarla desde la app TestFlight.

## 8. Notas importantes

- **La primera version externa de cada build requiere revision de Apple** el
  primer ciclo (aprobacion expresa de "Beta App Review"); puede tardar 1-2 dias
  habiles para externos (el enlace publico esta disponible al aprobar).
- **Los builds internos** aparecen de inmediato para los miembros del team
  Apple sin revision.
- **90 dias de vida util** por build de TestFlight; hay que re-subir una nueva
  build cuando caduca para seguir probando.
- **No se puede revocar** el enlace publico sin invalidar la URL.
- La app ya pide los permisos correctos; si aun asi la camara no abre en iOS,
  verificamos que `NSCameraUsageDescription` este en el target Runner (ya esta
  en `ios/Runner/Info.plist`) y que el proyecto iOS se haya generado con
  `flutter create .` reciente (no requiere accion salvo que falte el folder ios
  en futuras ramas).

## 9. Checklist rapida

- [ ] Mac con Xcode y Flutter OK.
- [ ] Team de firma seleccionado en Xcode.
- [ ] Build number nuevo en `pubspec.yaml`.
- [ ] `flutter build ipa --release` exitoso.
- [ ] App creada en App Store Connect con bundle `com.cubnex.app`.
- [ ] .ipa subido (Transporter) sin errores.
- [ ] Build procesado y activado en TestFlight.
- [ ] Testers internos o grupo externo creados; enlace enviado.