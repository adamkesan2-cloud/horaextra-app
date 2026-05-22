import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/domain/repositories/category_repository.dart';

class UpdateCategoryUseCase {
  final CategoryRepository _repository;

  UpdateCategoryUseCase(this._repository);

  Future<void> execute(CategoryModel category) async {
    return await _repository.updateCategory(category.id, category);
  }

  Future<void> executeFromMap(String id, Map<String, dynamic> data) async {
    // Primeiro busca a categoria existente
    final existing = await _repository.getCategoryById(id);

    // Atualiza com os novos dados
    final updated = existing.copyWith(
      name: data['name'],
      description: data['description'],
      icon: data['icon'],
      color: data['color'],
      isActive: data['isActive'],
    );

    return await _repository.updateCategory(id, updated);
  }

  Future<CategoryModel> toggleStatus(String id) async {
    return await _repository.toggleCategoryStatus(id);
  }
}
