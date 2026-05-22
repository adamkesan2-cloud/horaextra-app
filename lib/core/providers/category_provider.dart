// lib/core/providers/category_provider.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/domain/repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository =
      MockCategoryRepository() as CategoryRepository;
  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _repository.getAllCategories();
    } catch (e) {
      print('Erro ao carregar categorias: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    try {
      await _repository.createCategory(category);
      await loadCategories(); // Recarrega a lista
    } catch (e) {
      print('Erro ao adicionar categoria: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(String id, CategoryModel category) async {
    try {
      await _repository.updateCategory(id, category);
      await loadCategories(); // Recarrega a lista
    } catch (e) {
      print('Erro ao atualizar categoria: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
      await loadCategories(); // Recarrega a lista
    } catch (e) {
      print('Erro ao deletar categoria: $e');
      rethrow;
    }
  }

  // Método para buscar categorias ativas (para clientes)
  List<CategoryModel> getActiveCategories() {
    return _categories.where((c) => c.isActive).toList();
  }
}

class MockCategoryRepository {}
