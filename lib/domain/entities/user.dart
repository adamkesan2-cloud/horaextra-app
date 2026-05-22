// lib/domain/entities/user.dart
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? providerProfile;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
    this.providerProfile,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      photoUrl: json['photo_url']?.toString(),
      isActive: json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      providerProfile: json['provider_profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'photo_url': photoUrl,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'provider_profile': providerProfile,
      };
}
