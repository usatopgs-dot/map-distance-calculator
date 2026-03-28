import 'dart:math';

class Waypoint {
  final double lat;
  final double lng;
  final int index;

  const Waypoint({required this.lat, required this.lng, required this.index});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'index': index};

  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
        lat: json['lat'],
        lng: json['lng'],
        index: json['index'],
      );

  Waypoint copyWith({double? lat, double? lng, int? index}) => Waypoint(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        index: index ?? this.index,
      );
}

class SavedRoute {
  final String id;
  final String name;
  final List<Waypoint> waypoints;
  final double distanceKm;
  final String date;

  const SavedRoute({
    required this.id,
    required this.name,
    required this.waypoints,
    required this.distanceKm,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
        'distanceKm': distanceKm,
        'date': date,
      };

  factory SavedRoute.fromJson(Map<String, dynamic> json) => SavedRoute(
        id: json['id'],
        name: json['name'],
        waypoints: (json['waypoints'] as List)
            .map((w) => Waypoint.fromJson(w))
            .toList(),
        distanceKm: json['distanceKm'],
        date: json['date'],
      );
}

class RouteStats {
  final double distanceKm;
  final double distanceMiles;
  final int pointCount;
  final double? areaSqKm;

  const RouteStats({
    this.distanceKm = 0,
    this.distanceMiles = 0,
    this.pointCount = 0,
    this.areaSqKm,
  });

  String get carTime => _formatTime(distanceKm, 80);
  String get walkTime => _formatTime(distanceKm, 5);
  String get bikeTime => _formatTime(distanceKm, 20);

  String _formatTime(double km, double speed) {
    if (km == 0) return '—';
    final h = km / speed;
    if (h < 1) return '${(h * 60).round()}m';
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return mm > 0 ? '${hh}h ${mm}m' : '${hh}h';
  }
}

// Haversine formula - same as the original JS app
double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// Calculate polygon area in km²
double calculatePolygonArea(List<Waypoint> points) {
  if (points.length < 3) return 0;
  double area = 0;
  for (int i = 0; i < points.length; i++) {
    final j = (i + 1) % points.length;
    area += points[i].lng * points[j].lat;
    area -= points[j].lng * points[i].lat;
  }
  final absArea = (area / 2).abs();
  // Convert to km²
  return absArea * pow(111320, 2) * cos(points[0].lat * pi / 180) / 1e6;
}
