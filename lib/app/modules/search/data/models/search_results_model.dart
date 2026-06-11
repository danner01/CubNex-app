import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/product_model.dart';

class SearchResultsModel {
  const SearchResultsModel({
    this.businesses = const [],
    this.products = const [],
    this.properties = const [],
    this.transport = const [],
  });

  final List<BusinessModel> businesses;
  final List<ProductModel> products;
  final List<SearchAssetModel> properties;
  final List<SearchAssetModel> transport;

  bool get isEmpty =>
      businesses.isEmpty &&
      products.isEmpty &&
      properties.isEmpty &&
      transport.isEmpty;

  int get totalCount =>
      businesses.length +
      products.length +
      properties.length +
      transport.length;

  bool hasPageWithAtLeast(int limit) {
    return businesses.length >= limit ||
        products.length >= limit ||
        properties.length >= limit ||
        transport.length >= limit;
  }

  SearchResultsModel merge(SearchResultsModel next) {
    return SearchResultsModel(
      businesses: [...businesses, ...next.businesses],
      products: [...products, ...next.products],
      properties: [...properties, ...next.properties],
      transport: [...transport, ...next.transport],
    );
  }

  factory SearchResultsModel.fromJson(Map<String, dynamic> json) {
    return SearchResultsModel(
      businesses: _asList(
        json['negocios'],
      ).map((item) => BusinessModel.fromJson(item)).toList(),
      products: _asList(
        json['productos'],
      ).map((item) => ProductModel.fromJson(item)).toList(),
      properties: _asList(
        json['propiedades'],
      ).map((item) => SearchAssetModel.fromJson(item)).toList(),
      transport: _asList(
        json['transporte'],
      ).map((item) => SearchAssetModel.fromJson(item)).toList(),
    );
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }
}

class SearchAssetModel {
  const SearchAssetModel({
    required this.id,
    required this.title,
    this.description,
    this.type,
    this.price,
    this.currency,
    this.province,
    this.municipality,
  });

  final String id;
  final String title;
  final String? description;
  final String? type;
  final double? price;
  final String? currency;
  final String? province;
  final String? municipality;

  factory SearchAssetModel.fromJson(Map<String, dynamic> json) {
    return SearchAssetModel(
      id: '${json['id'] ?? ''}',
      title: '${json['titulo'] ?? json['nombre'] ?? ''}',
      description: json['descripcion']?.toString(),
      type: json['tipo']?.toString(),
      price: double.tryParse(
        '${json['precio'] ?? json['precio_base'] ?? json['precio_por_km'] ?? ''}',
      ),
      currency: json['moneda']?.toString(),
      province: json['provincia']?.toString(),
      municipality: json['municipio']?.toString(),
    );
  }
}
