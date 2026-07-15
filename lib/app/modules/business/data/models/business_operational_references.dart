class BusinessOperationalReferences {
  const BusinessOperationalReferences({
    required this.sales,
    required this.products,
    required this.reviews,
    required this.promotions,
  });

  final int sales;
  final int products;
  final int reviews;
  final int promotions;

  BusinessOperationalReferences copyWith({
    int? sales,
    int? products,
    int? reviews,
    int? promotions,
  }) {
    return BusinessOperationalReferences(
      sales: sales ?? this.sales,
      products: products ?? this.products,
      reviews: reviews ?? this.reviews,
      promotions: promotions ?? this.promotions,
    );
  }
}
