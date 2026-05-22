class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String categoryName;
  final double rating;
  final int reviewCount;
  final bool isAvailable;
  final int estimatedTime; // CAMPO ADICIONADO
  final DateTime createdAt;
  final DateTime? updatedAt;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isAvailable = true,
    required this.estimatedTime, // CAMPO OBRIGATÓRIO
    required this.createdAt,
    this.updatedAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: _toDouble(json['price']),
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: _getCategoryName(json),
      rating: _toDouble(json['rating']),
      reviewCount: _toInt(json['review_count']),
      isAvailable: json['is_available'] ?? true,
      estimatedTime: _toInt(json['estimated_time']), // CAMPO ADICIONADO
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  String? get imageUrl => null;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _getCategoryName(Map<String, dynamic> json) {
    if (json['category'] != null && json['category']['name'] != null) {
      return json['category']['name'].toString();
    }
    return json['category_name']?.toString() ?? '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'category_name': categoryName,
      'rating': rating,
      'review_count': reviewCount,
      'is_available': isAvailable,
      'estimated_time': estimatedTime, // CAMPO ADICIONADO
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ServiceModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? categoryName,
    double? rating,
    int? reviewCount,
    bool? isAvailable,
    int? estimatedTime, // CAMPO ADICIONADO
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isAvailable: isAvailable ?? this.isAvailable,
      estimatedTime: estimatedTime ?? this.estimatedTime, // CAMPO ADICIONADO
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static List<ServiceModel> getMockServices() {
    return [
      ServiceModel(
        id: '1',
        name: 'Limpeza Residencial Completa',
        description: 'Limpeza completa de residências',
        price: 1500.0,
        categoryId: '1',
        categoryName: 'Limpeza',
        rating: 4.8,
        reviewCount: 156,
        isAvailable: true,
        estimatedTime: 180, // 3 horas
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      ServiceModel(
        id: '2',
        name: 'Instalação Elétrica',
        description: 'Instalação e manutenção de sistemas elétricos',
        price: 2000.0,
        categoryId: '2',
        categoryName: 'Elétrica',
        rating: 4.9,
        reviewCount: 203,
        isAvailable: true,
        estimatedTime: 120, // 2 horas
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      ServiceModel(
        id: '3',
        name: 'Reparo Hidráulico',
        description: 'Conserto de vazamentos e torneiras',
        price: 1200.0,
        categoryId: '3',
        categoryName: 'Hidráulica',
        rating: 4.7,
        reviewCount: 98,
        isAvailable: true,
        estimatedTime: 90, // 1.5 horas
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    ];
  }
}
