class AppEnvironment {
  const AppEnvironment._();

  static const productionApiBaseUrl =
      'https://supermarket-superadmin-rfz6.vercel.app';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionApiBaseUrl,
  );

  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const appScheme = 'cubnex';
}
