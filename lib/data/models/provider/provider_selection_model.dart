// lib/data/models/provider/provider_selection_model.dart
class ProviderSelectionModel {
  final String id;
  final String name;
  final String photoUrl;
  final double rating;
  final int reviewCount;
  final double distance;
  final double price;
  final List<String> specialties;
  final int completedJobs;
  final int responseRate;
  final int acceptanceRate;
  final bool isAvailable;
  final double matchScore;
  final bool isOnline;
  final bool isSelected;
  final double latitude;
  final double longitude;

  ProviderSelectionModel({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.price,
    required this.specialties,
    required this.completedJobs,
    required this.responseRate,
    required this.acceptanceRate,
    required this.isAvailable,
    required this.matchScore,
    required this.isOnline,
    this.isSelected = false,
    required this.latitude,
    required this.longitude,
  });

  ProviderSelectionModel copyWith({
    String? id,
    String? name,
    String? photoUrl,
    double? rating,
    int? reviewCount,
    double? distance,
    double? price,
    List<String>? specialties,
    int? completedJobs,
    int? responseRate,
    int? acceptanceRate,
    bool? isAvailable,
    double? matchScore,
    bool? isOnline,
    bool? isSelected,
    double? latitude,
    double? longitude,
  }) {
    return ProviderSelectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distance: distance ?? this.distance,
      price: price ?? this.price,
      specialties: specialties ?? this.specialties,
      completedJobs: completedJobs ?? this.completedJobs,
      responseRate: responseRate ?? this.responseRate,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      isAvailable: isAvailable ?? this.isAvailable,
      matchScore: matchScore ?? this.matchScore,
      isOnline: isOnline ?? this.isOnline,
      isSelected: isSelected ?? this.isSelected,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory ProviderSelectionModel.fromJson(Map<String, dynamic> json) {
    return ProviderSelectionModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Prestador',
      photoUrl: json['photoUrl'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      specialties: (json['specialties'] as List?)?.cast<String>() ?? [],
      completedJobs: json['completedJobs'] as int? ?? 0,
      responseRate: json['responseRate'] as int? ?? 100,
      acceptanceRate: json['acceptanceRate'] as int? ?? 100,
      isAvailable: json['isAvailable'] as bool? ?? false,
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0.0,
      isOnline: json['isOnline'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble() ?? -25.9692,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 32.5732,
    );
  }

  get about => null;

  get location => null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photoUrl': photoUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'distance': distance,
      'price': price,
      'specialties': specialties,
      'completedJobs': completedJobs,
      'responseRate': responseRate,
      'acceptanceRate': acceptanceRate,
      'isAvailable': isAvailable,
      'matchScore': matchScore,
      'isOnline': isOnline,
      'isSelected': isSelected,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}