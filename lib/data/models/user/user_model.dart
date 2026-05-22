// lib/data/models/user/user_model.dart
class UserModel {
  String id;
  String name;
  String email;
  String? phone;
  String role;
  String? photoUrl;
  String? address;
  String? city;
  String? postalCode;
  bool isActive;
  bool isVerified;
  DateTime? createdAt;
  DateTime? lastLoginAt;
  Map<String, dynamic>? location;
  Map<String, dynamic>? metadata;
  Map<String, dynamic>? providerProfile; // Adicionado

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.photoUrl,
    this.address,
    this.city,
    this.postalCode,
    this.isActive = true,
    this.isVerified = false,
    this.createdAt,
    this.lastLoginAt,
    this.location,
    this.metadata,
    this.providerProfile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'client',
      photoUrl: json['photo_url']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      postalCode: json['postal_code']?.toString(),
      isActive: json['is_active'] == true,
      isVerified: json['is_verified'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'])
          : null,
      location: json['location'] is Map
          ? Map<String, dynamic>.from(json['location'])
          : null,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      providerProfile: json['providerProfile'] is Map
          ? Map<String, dynamic>.from(json['providerProfile'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'photo_url': photoUrl,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt?.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'location': location,
      'metadata': metadata,
      'providerProfile': providerProfile,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? photoUrl,
    String? address,
    String? city,
    String? postalCode,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? location,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? providerProfile,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      location: location ?? this.location,
      metadata: metadata ?? this.metadata,
      providerProfile: providerProfile ?? this.providerProfile,
    );
  }
}
