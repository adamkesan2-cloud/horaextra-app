// lib/data/models/location/route_info.dart
import 'package:latlong2/latlong.dart';

class RouteInfo {
  final double distanceKm;
  final double durationMin;
  final List<LatLng> points;
  final String polyline;

  RouteInfo({
    required this.distanceKm,
    required this.durationMin,
    required this.points,
    required this.polyline,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
        distanceKm: (json['distance_km'] ?? 0).toDouble(),
        durationMin: (json['duration_min'] ?? 0).toDouble(),
        points: (json['points'] as List?)
                ?.map((p) => LatLng(p['lat'], p['lng']))
                .toList() ??
            [],
        polyline: json['polyline'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'points':
            points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'polyline': polyline,
      };
}
