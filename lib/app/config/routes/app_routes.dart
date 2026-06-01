class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const home = '/home';
  static const search = '/search';
  static const map = '/map';
  static const scanner = '/scanner';
  static const scanHistory = '/scan-history';
  static const favorites = '/favorites';
  static const cart = '/cart';
  static const orders = '/orders';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const preferences = '/preferences-v2';
  static const gamification = '/gamification';
  static const promotions = '/promotions';
  static const posts = '/posts';
  static const myReviews = '/my-reviews';
  static const properties = '/properties';
  static const transport = '/transport';
  static const propertyDetail = '/properties/:id';
  static const transportDetail = '/transport/:id';
  static const businessPromotions = '/business/promotions';
  static const businessProperties = '/business/properties';
  static const businessTransport = '/business/transport';
  static const businessMenus = '/business/menus';
  static const businessOrders = '/business/orders';
  static const productDetail = '/product/:id';
  static const businessDetail = '/store/:id';
  static const businessDashboard = '/business/dashboard';
  static const businessInventory = '/business/inventory';
  static const businessSettings = '/business/settings';
  static const businessWizard = '/business/wizard';

  static String product(String id) => '/product/$id';
  static String store(String id) => '/store/$id';
  static String property(String id) => '/properties/$id';
  static String transportService(String id) => '/transport/$id';
}
