import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/domain/repositories/service_repository.dart';

class GetServicesUseCase {
  final ServiceRepository _repository;

  GetServicesUseCase(this._repository);

  Future<List<ServiceModel>> execute() async {
    return await _repository.getAllServices();
  }

  Future<List<ServiceModel>> getByCategory(String categoryId) async {
    return await _repository.getServicesByCategory(categoryId);
  }

  Future<List<ServiceModel>> search(String query) async {
    return await _repository.searchServices(query);
  }
}
