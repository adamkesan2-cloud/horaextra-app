// lib/data/models/provider/provider_model.dart
import 'dart:convert';

class ProviderModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final double latitude;
  final double longitude;
  final double rating;
  final int completedJobs;
  final double price;
  final bool isOnline;
  final List<String> specialties;
  final double distance;
  final String? phone;
  final String? address;

  const ProviderModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.completedJobs,
    required this.price,
    required this.isOnline,
    required this.specialties,
    required this.distance,
    this.phone,
    this.address,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    final loc = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : <String, dynamic>{};

    final lat = _toDouble(
        loc['lat'] ?? loc['latitude'] ?? json['latitude'] ?? -25.9692);
    final lng = _toDouble(
        loc['lng'] ?? loc['longitude'] ?? json['longitude'] ?? 32.5732);
    final specs = _parseSpecialties(json['specialties']);
    final id = (user['id'] ?? json['user_id'] ?? json['id'] ?? '').toString();

    return ProviderModel(
      id: id,
      name: (user['name'] ?? json['name'] ?? 'Prestador').toString(),
      email: (user['email'] ?? json['email'] ?? '').toString(),
      photoUrl: (user['photo_url'] ?? json['photo_url'] ?? json['photoUrl'])
          ?.toString(),
      latitude: lat,
      longitude: lng,
      rating: _toDouble(json['rating'] ?? 0),
      completedJobs:
          _toInt(json['completed_jobs'] ?? json['completedJobs'] ?? 0),
      price: _toDouble(json['price'] ?? 1500),
      isOnline: _toBool(json['is_available'] ??
          json['isOnline'] ??
          json['is_online'] ??
          true),
      specialties: specs,
      distance: _toDouble(json['distance'] ?? 0),
      phone: user['phone']?.toString() ?? json['phone']?.toString(),
      address: loc['address']?.toString() ?? json['address']?.toString(),
    );
  }

  static List<String> _parseSpecialties(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      if (raw.startsWith('[')) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [raw];
    }
    return [];
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'rating': rating,
        'completedJobs': completedJobs,
        'price': price,
        'isOnline': isOnline,
        'specialties': specialties,
        'distance': distance,
        'phone': phone,
        'address': address,
      };
}
