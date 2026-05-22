  // lib/data/models/notification/notification_model.dart
import 'package:flutter/material.dart';

enum NotificationType {
  request,      // Nova solicitação de serviço
  response,     // Resposta do prestador (aceite/recusa)
  status,       // Mudança de status do serviço
  message,      // Mensagem do prestador/cliente
  payment,      // Pagamento recebido
  rating,       // Nova avaliação
  promotion,    // Promoção/desconto
  system,       // Notificação do sistema
  location,     // Atualização de localização
  completion,   // Serviço concluído
}

enum NotificationPriority {
  low,      // Baixa prioridade (ex: promoções)
  normal,   // Normal
  high,     // Alta prioridade (ex: novo pedido)
  urgent,   // Urgente (ex: cancelamento)
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? subtitle;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final String? actionRoute;
  final Map<String, dynamic>? actionParams;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.subtitle,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    this.data,
    this.actionRoute,
    this.actionParams,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _parseNotificationType(json['type']),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      isRead: json['isRead'] == true,
      priority: _parseNotificationPriority(json['priority']),
      data: json['data'] as Map<String, dynamic>?,
      actionRoute: json['actionRoute']?.toString(),
      actionParams: json['actionParams'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'message': message,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'priority': priority.name,
    'data': data,
    'actionRoute': actionRoute,
    'actionParams': actionParams,
  };

  static NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'request': return NotificationType.request;
      case 'response': return NotificationType.response;
      case 'status': return NotificationType.status;
      case 'message': return NotificationType.message;
      case 'payment': return NotificationType.payment;
      case 'rating': return NotificationType.rating;
      case 'promotion': return NotificationType.promotion;
      case 'system': return NotificationType.system;
      case 'location': return NotificationType.location;
      case 'completion': return NotificationType.completion;
      default: return NotificationType.system;
    }
  }

  static NotificationPriority _parseNotificationPriority(String? priority) {
    switch (priority) {
      case 'low': return NotificationPriority.low;
      case 'high': return NotificationPriority.high;
      case 'urgent': return NotificationPriority.urgent;
      default: return NotificationPriority.normal;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.request:
        return Icons.notifications_active_rounded;
      case NotificationType.response:
        return Icons.check_circle_rounded;
      case NotificationType.status:
        return Icons.update_rounded;
      case NotificationType.message:
        return Icons.message_rounded;
      case NotificationType.payment:
        return Icons.payments_rounded;
      case NotificationType.rating:
        return Icons.star_rounded;
      case NotificationType.promotion:
        return Icons.local_offer_rounded;
      case NotificationType.completion:
        return Icons.done_all_rounded;
      case NotificationType.location:
        return Icons.location_on_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (priority) {
      case NotificationPriority.urgent:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.normal:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.grey;
    }
  }
}