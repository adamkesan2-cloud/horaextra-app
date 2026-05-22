// lib/data/models/location/location_model.dart
import 'package:latlong2/latlong.dart';

class LocationModel {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime timestamp;

  LocationModel({
    required this.latitude,
    required this.longitude,
    this.address,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  LatLng get latLng => LatLng(latitude, longitude);

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        latitude: (json['latitude'] ?? 0).toDouble(),
        longitude: (json['longitude'] ?? 0).toDouble(),
        address: json['address'],
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'timestamp': timestamp.toIso8601String(),
      };
}

// RouteInfo agora está em seu próprio arquivo - NÃO incluir aqui!
