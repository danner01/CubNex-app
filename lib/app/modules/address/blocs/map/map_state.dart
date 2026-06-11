import '../../data/models/map_search_item.dart';

enum MapStatus { initial, loading, success, failure }

class MapRoutePoint {
  const MapRoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class MapState {
  const MapState({
    this.status = MapStatus.initial,
    this.items = const [],
    this.selectedType,
    this.latitude = 23.1136,
    this.longitude = -82.3666,
    this.userLatitude = 23.1136,
    this.userLongitude = -82.3666,
    this.query = '',
    this.message,
    this.locating = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.offset = 0,
    this.limit = 10,
    this.routePoints = const [],
    this.routeTargetId,
  });

  final MapStatus status;
  final List<MapSearchItem> items;
  final MapSearchType? selectedType;
  final double latitude;
  final double longitude;
  final double userLatitude;
  final double userLongitude;
  final String query;
  final String? message;
  final bool locating;
  final bool loadingMore;
  final bool hasMore;
  final int offset;
  final int limit;
  final List<MapRoutePoint> routePoints;
  final String? routeTargetId;

  List<MapSearchItem> get visibleItems {
    final type = selectedType;
    if (type == null) return items;
    return items.where((item) => item.type == type).toList();
  }

  MapState copyWith({
    MapStatus? status,
    List<MapSearchItem>? items,
    MapSearchType? selectedType,
    bool clearSelectedType = false,
    double? latitude,
    double? longitude,
    double? userLatitude,
    double? userLongitude,
    String? query,
    String? message,
    bool clearMessage = false,
    bool? locating,
    bool? loadingMore,
    bool? hasMore,
    int? offset,
    int? limit,
    List<MapRoutePoint>? routePoints,
    String? routeTargetId,
    bool clearRoute = false,
  }) {
    return MapState(
      status: status ?? this.status,
      items: items ?? this.items,
      selectedType: clearSelectedType
          ? null
          : selectedType ?? this.selectedType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      query: query ?? this.query,
      message: clearMessage ? null : message ?? this.message,
      locating: locating ?? this.locating,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      routePoints: clearRoute ? const [] : routePoints ?? this.routePoints,
      routeTargetId: clearRoute ? null : routeTargetId ?? this.routeTargetId,
    );
  }
}
