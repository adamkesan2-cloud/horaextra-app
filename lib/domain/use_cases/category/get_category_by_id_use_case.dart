import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/domain/repositories/category_repository.dart';

class GetCategoryByIdUseCase {
  final CategoryRepository _repository;

  GetCategoryByIdUseCase(this._repository);

  Future<CategoryModel> execute(String id) async {
    return await _repository.getCategoryById(id);
  }
}
