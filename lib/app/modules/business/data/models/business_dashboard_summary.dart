import '../../../home/data/models/business_model.dart';

class BusinessDashboardSummary {
  const BusinessDashboardSummary({
    required this.business,
    this.products = 0,
    this.reviews = 0,
    this.promotions = 0,
    this.properties = 0,
    this.transport = 0,
    this.menus = 0,
    this.points = 0,
    this.sales = 0,
    this.level = 'bronce',
  });

  final BusinessModel business;
  final int products;
  final int reviews;
  final int promotions;
  final int properties;
  final int transport;
  final int menus;
  final int points;
  final int sales;
  final String level;

  BusinessDashboardSummary copyWith({
    BusinessModel? business,
    int? products,
    int? reviews,
    int? promotions,
    int? properties,
    int? transport,
    int? menus,
    int? points,
    int? sales,
    String? level,
  }) {
    return BusinessDashboardSummary(
      business: business ?? this.business,
      products: products ?? this.products,
      reviews: reviews ?? this.reviews,
      promotions: promotions ?? this.promotions,
      properties: properties ?? this.properties,
      transport: transport ?? this.transport,
      menus: menus ?? this.menus,
      points: points ?? this.points,
      sales: sales ?? this.sales,
      level: level ?? this.level,
    );
  }

  double get completeness {
    var score = 0;
    if ((business.logoUrl ?? '').isNotEmpty) score++;
    if ((business.bannerUrl ?? '').isNotEmpty) score++;
    if ((business.description ?? '').isNotEmpty) score++;
    if ((business.phone ?? '').isNotEmpty ||
        (business.whatsapp ?? '').isNotEmpty) {
      score++;
    }
    if ((business.province ?? '').isNotEmpty ||
        (business.municipality ?? '').isNotEmpty) {
      score++;
    }
    return score / 5;
  }
}
