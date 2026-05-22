import 'dart:typed_data';

class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String? color;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? imageName;
  final bool isActive;
  final int order;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.color,
    this.imageUrl,
    this.imageBytes,
    this.imageName,
    this.isActive = true,
    required this.order,
    required this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    // Função segura para converter para int
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // Função segura para converter para String
    String safeString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    // Função segura para converter para bool
    bool safeBool(dynamic value) {
      if (value == null) return true;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return true;
    }

    // Função segura para converter para DateTime
    DateTime? safeDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return CategoryModel(
      id: safeString(json['id']),
      name: safeString(json['name']),
      description: safeString(json['description']),
      icon: safeString(json['icon']),
      color: safeString(json['color']),
      imageUrl: safeString(json['image_url']),
      imageBytes: null,
      imageName: null,
      isActive: safeBool(json['is_active']),
      order: safeInt(json['order']), // AGORA SEMPRE RETORNA UM INT
      createdAt: safeDate(json['created_at']) ?? DateTime.now(),
      updatedAt: safeDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'image_url': imageUrl,
      'is_active': isActive,
      'order': order,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    String? imageUrl,
    Uint8List? imageBytes,
    String? imageName,
    bool? isActive,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
      imageName: imageName ?? this.imageName,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static List<CategoryModel> getMockCategories() {
    return [
      CategoryModel(
        id: '1',
        name: 'Limpeza',
        description: 'Serviços de limpeza residencial e comercial',
        icon: 'cleaning_services',
        color: '#3B82F6',
        order: 1,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '2',
        name: 'Elétrica',
        description: 'Instalações e reparos elétricos',
        icon: 'electric_bolt',
        color: '#F59E0B',
        order: 2,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '3',
        name: 'Hidráulica',
        description: 'Encanamento e reparos hidráulicos',
        icon: 'plumbing',
        color: '#10B981',
        order: 3,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '4',
        name: 'Pintura',
        description: 'Pintura de interiores e exteriores',
        icon: 'format_paint',
        color: '#EF4444',
        order: 4,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '5',
        name: 'Jardinagem',
        description: 'Cuidados com jardins e áreas verdes',
        icon: 'eco',
        color: '#10B981',
        order: 5,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '6',
        name: 'Montagem',
        description: 'Montagem de móveis e equipamentos',
        icon: 'construction',
        color: '#8B5CF6',
        order: 6,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '7',
        name: 'Marcenaria',
        description: 'Serviços de marcenaria e reparos em madeira',
        icon: 'handyman',
        color: '#EC4899',
        order: 7,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      CategoryModel(
        id: '8',
        name: 'Pets',
        description: 'Cuidados e serviços para animais de estimação',
        icon: 'pets',
        color: '#14B8A6',
        order: 8,
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];
  }
}
