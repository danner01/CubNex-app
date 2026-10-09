class WebMapMarker {
  const WebMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.color = '#D32F2F',
  });

  final String id;
  final double latitude;
  final double longitude;
  final String color;
}

class WebMapRoute {
  const WebMapRoute({
    required this.id,
    required this.coordinates,
    this.color = '#1976D2',
    this.width = 5,
  });

  final String id;
  final List<List<double>> coordinates;
  final String color;
  final double width;
}
