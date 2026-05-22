// lib/core/adapters/service_adapter.dart
import 'package:horaextra_app/data/models/service/service_model.dart';

class ServiceAdapter {
  // Converte ServiceModel para o formato Map usado nos cards do provider
  static Map<String, dynamic> serviceModelToProviderMap(ServiceModel service) {
    return {
      'id': service.id,
      'title': service.name,
      'description': service.description,
      'price': service.price,
      'category': service.categoryName,
      'service_id': service.id,
      'client_name': 'Cliente', // Mock - substituir quando tiver dados reais
      'client_address': 'Endereço do cliente',
      'date': DateTime.now(),
      'status': service.isAvailable ? 'available' : 'unavailable',
      'rating': service.rating,
      'reviewCount': service.reviewCount,
    };
  }

  // Converte lista de ServiceModel para lista de Map
  static List<Map<String, dynamic>> serviceModelListToProviderMap(
      List<ServiceModel> services) {
    return services
        .map((service) => serviceModelToProviderMap(service))
        .toList();
  }

  // Para serviços ativos (com dados adicionais)
  static Map<String, dynamic> createActiveServiceMap(
    ServiceModel service, {
    required String clientName,
    required String clientAddress,
    DateTime? startTime,
  }) {
    return {
      'id': service.id,
      'title': service.name,
      'description': service.description,
      'price': service.price,
      'category': service.categoryName,
      'service_id': service.id,
      'client_name': clientName,
      'client_address': clientAddress,
      'date': startTime ?? DateTime.now(),
      'start_time': startTime ?? DateTime.now(),
      'status': 'in_progress',
      'rating': service.rating,
    };
  }

  // Para pedidos pendentes
  static Map<String, dynamic> createPendingRequestMap(
    ServiceModel service, {
    required String clientName,
    required String clientAddress,
    required DateTime scheduledDate,
  }) {
    return {
      'id': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'title': service.name,
      'description': service.description,
      'price': service.price,
      'category': service.categoryName,
      'service_id': service.id,
      'client_name': clientName,
      'client_address': clientAddress,
      'date': scheduledDate,
      'status': 'pending',
    };
  }

  // Para histórico de serviços
  static Map<String, dynamic> createHistoryMap(
    ServiceModel service, {
    required String clientName,
    required DateTime completedAt,
    required double rating,
  }) {
    return {
      'id': 'hist_${DateTime.now().millisecondsSinceEpoch}',
      'title': service.name,
      'description': service.description,
      'price': service.price,
      'category': service.categoryName,
      'service_id': service.id,
      'client_name': clientName,
      'date': completedAt,
      'completed_at': completedAt,
      'status': 'completed',
      'rating': rating,
    };
  }
}
