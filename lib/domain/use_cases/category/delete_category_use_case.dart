import 'package:horaextra_app/domain/repositories/category_repository.dart';

class DeleteCategoryUseCase {
  final CategoryRepository _repository;

  DeleteCategoryUseCase(this._repository);

  Future<void> execute(String id) async {
    return await _repository.deleteCategory(id);
  }
}
