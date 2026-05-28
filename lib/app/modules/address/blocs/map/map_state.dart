import '../../data/models/map_search_item.dart';

enum MapStatus { initial, loading, success, failure }

class MapState {
  const MapState({
    this.status = MapStatus.initial,
    this.items = const [],
    this.selectedType,
    this.latitude = 23.1136,
    this.longitude = -82.3666,
    this.query = '',
    this.message,
    this.locating = false,
  });

  final MapStatus status;
  final List<MapSearchItem> items;
  final MapSearchType? selectedType;
  final double latitude;
  final double longitude;
  final String query;
  final String? message;
  final bool locating;

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
    String? query,
    String? message,
    bool clearMessage = false,
    bool? locating,
  }) {
    return MapState(
      status: status ?? this.status,
      items: items ?? this.items,
      selectedType: clearSelectedType ? null : selectedType ?? this.selectedType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      query: query ?? this.query,
      message: clearMessage ? null : message ?? this.message,
      locating: locating ?? this.locating,
    );
  }
}
