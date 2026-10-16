class AppEnvironment {
  const AppEnvironment._();

  static const productionApiBaseUrl =
      'https://supermarket-superadmin.vercel.app';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionApiBaseUrl,
  );

  static const apkUpdateManifestUrl = String.fromEnvironment(
    'APK_UPDATE_MANIFEST_URL',
    defaultValue:
        'https://supermarket-superadmin.vercel.app/api/apk/latest',
  );

  static const apkLandingUrl = '$productionApiBaseUrl/apk';
  static const apkPrivacyPolicyUrl = '$apkLandingUrl/privacidad';
  static const apkTermsUrl = '$apkLandingUrl/terminos';

  // PWA publica de la Casa de Cambio (CADECA). La casa seleccionada se pasa
  // como query (?casa=<slug>) para que el usuario entre directo a su sede.
  static const cadecaBaseUrl = String.fromEnvironment(
    'CADECA_BASE_URL',
    defaultValue: 'https://conkkao-cadeca.vercel.app',
  );

  static String cadecaUrl({String? casa}) {
    final slug = casa?.trim();
    if (slug == null || slug.isEmpty) return cadecaBaseUrl;
    return Uri.parse(cadecaBaseUrl).replace(
      queryParameters: {'casa': slug},
    ).toString();
  }

  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue:
        'pk.eyJ1IjoiZGFubmVyMjMiLCJhIjoiY2xqOHJ5dnJyMHd3azNnbzUydXQydWdyZiJ9.nacD5xQ8evU0nra5jgpXLQ',
  );

  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '182405994803-461d6n4h4vq5jfu6i2eu8le71se75dlc.apps.googleusercontent.com',
  );

  static const appScheme = 'cubnex';

  // Web Push certificate (VAPID) del proyecto Firebase, requerida para que el
  // navegador pueda suscribirse a las notificaciones push en la PWA.
  static const firebaseWebVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue:
        'BHdAFWT-a5WvXq9RkOKr3VasuODkm5oJgUuXGaqxBwTGkpsWxekzEG75fT_E1K1CbPKix12rlsEdBH4EE8oeUTM',
  );
}
