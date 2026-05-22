import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/domain/repositories/service_repository.dart';

class GetServiceByIdUseCase {
  final ServiceRepository _repository;

  GetServiceByIdUseCase(this._repository);

  Future<ServiceModel> execute(String id) async {
    return await _repository.getServiceById(id);
  }
}
