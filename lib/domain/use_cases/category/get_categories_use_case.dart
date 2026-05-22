import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/domain/repositories/category_repository.dart';

class GetCategoriesUseCase {
  final CategoryRepository _repository;

  GetCategoriesUseCase(this._repository);

  Future<List<CategoryModel>> execute() async {
    return await _repository.getAllCategories();
  }

  Future<List<CategoryModel>> search(String query) async {
    return await _repository.searchCategories(query);
  }

  Future<List<CategoryModel>> getActive() async {
    final all = await _repository.getAllCategories();
    return all.where((c) => c.isActive).toList();
  }
}
