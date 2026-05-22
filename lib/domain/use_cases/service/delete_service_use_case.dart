import 'package:horaextra_app/domain/repositories/service_repository.dart';

class DeleteServiceUseCase {
  final ServiceRepository _repository;

  DeleteServiceUseCase(this._repository);

  Future<void> execute(String id) async {
    return await _repository.deleteService(id);
  }
}
