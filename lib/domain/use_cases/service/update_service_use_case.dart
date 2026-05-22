import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/domain/repositories/service_repository.dart';

class UpdateServiceUseCase {
  final ServiceRepository _repository;

  UpdateServiceUseCase(this._repository);

  Future<void> execute(ServiceModel service) async {
    return await _repository.updateService(service.id, service);
  }

  Future<void> executeFromMap(String id, Map<String, dynamic> data) async {
    // Primeiro busca o serviço existente
    final existing = await _repository.getServiceById(id);

    // Atualiza com os novos dados
    final updated = existing.copyWith(
      name: data['name'],
      description: data['description'],
      price: data['price'] != null ? (data['price'] as num).toDouble() : null,
      categoryId: data['categoryId'],
      categoryName: data['categoryName'],
      isAvailable: data['isAvailable'],
    );

    return await _repository.updateService(id, updated);
  }

  Future<ServiceModel> toggleStatus(String id) async {
    return await _repository.toggleServiceStatus(id);
  }
}
