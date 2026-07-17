class AppEnvironment {
  const AppEnvironment._();

  static const productionApiBaseUrl =
      'https://supermarket-superadmin-rfz6.vercel.app';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionApiBaseUrl,
  );

  static const apkUpdateManifestUrl = String.fromEnvironment(
    'APK_UPDATE_MANIFEST_URL',
    defaultValue:
        'https://supermarket-superadmin-rfz6.vercel.app/api/apk/latest',
  );

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
}
