# Correccion de Google Sign-In en CubNex

Error visto:

```text
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10)
```

Ese error significa que Google no reconoce la app Android que intenta iniciar sesion.

## Datos actuales de la APK

Paquete Android:

```text
com.cubnex.app
```

SHA debug detectado en esta maquina:

```text
SHA1: BA:A8:21:8A:F8:8E:A6:49:42:28:36:D9:0C:C6:66:C2:C8:B3:18:F1
SHA256: B1:FB:C5:0F:14:48:DA:78:31:2A:8B:93:3A:A3:26:6E:88:A8:7A:A1:67:79:9F:2B:4D:DF:17:AD:37:51:35:C6
```

## Pasos en Firebase

1. Ir a Firebase Console > proyecto `supermarkercuba`.
2. Agregar una app Android nueva.
3. Package name:

```text
com.cubnex.app
```

4. Agregar SHA-1 y SHA-256 anteriores.
5. Descargar `google-services.json`.
6. Copiarlo en:

```text
android/app/google-services.json
```

7. En Authentication > Sign-in method, habilitar Google.
8. En Google Cloud Console > APIs & Services > Credentials, copiar el Web Client ID.
9. Ejecutar la app con:

```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=TU_WEB_CLIENT_ID.apps.googleusercontent.com
```

## Para release

Cuando se cree el keystore de release, ejecutar:

```bash
keytool -list -v -keystore RUTA_DEL_KEYSTORE -alias ALIAS
```

Agregar tambien el SHA-1/SHA-256 de release a Firebase. Si no se agrega, Google login funcionara en debug pero fallara en APK/AAB release.
