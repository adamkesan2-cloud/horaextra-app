// lib/domain/repositories/category_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';

class CategoryRepository {
  final ApiService _apiService;

  CategoryRepository(this._apiService);

  String _url(String path) => '${ApiConfig.baseUrl}$path';

  Future<String?> _token() async => await _apiService.authProvider?.getToken();

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Métodos principais ────────────────────────────────────────────────────

  Future<List<CategoryModel>> getAll() async {
    try {
      final token = await _token();
      final res = await http
          .get(Uri.parse(_url('/categories')), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.map((j) => CategoryModel.fromJson(j)).toList();
        }
      }
      debugPrint('❌ getAll categories: ${res.statusCode}');
    } catch (e) {
      debugPrint('❌ getAll categories: $e');
    }
    return [];
  }

  Future<CategoryModel?> getById(String id) async {
    try {
      final token = await _token();
      final res = await http
          .get(Uri.parse(_url('/categories/$id')), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return CategoryModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('❌ getById category: $e');
    }
    return null;
  }

  Future<CategoryModel?> create(Map<String, dynamic> data) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .post(Uri.parse(_url('/categories')),
              headers: _headers(token), body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 201) {
        return CategoryModel.fromJson(jsonDecode(res.body));
      }
      debugPrint('❌ create category: ${res.statusCode}');
    } catch (e) {
      debugPrint('❌ create category: $e');
    }
    return null;
  }

  Future<CategoryModel?> update(String id, Map<String, dynamic> data) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .put(Uri.parse(_url('/categories/$id')),
              headers: _headers(token), body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return CategoryModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('❌ update category: $e');
    }
    return null;
  }

  Future<bool> delete(String id) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .delete(Uri.parse(_url('/categories/$id')), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('❌ delete category: $e');
      return false;
    }
  }

  Future<CategoryModel?> toggleStatus(String id) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .patch(Uri.parse(_url('/categories/$id/toggle')),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return CategoryModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('❌ toggleStatus category: $e');
    }
    return null;
  }

  Future<List<CategoryModel>> search(String query) async {
    final all = await getAll();
    final lower = query.toLowerCase();
    return all.where((c) => c.name.toLowerCase().contains(lower)).toList();
  }

  // ── Aliases para use cases / providers existentes ─────────────────────────
  // Mantêm compatibilidade sem alterar os ficheiros que os chamam.

  /// Alias de [getAll]
  Future<List<CategoryModel>> getAllCategories() => getAll();

  /// Alias de [getById] — devolve CategoryModel (lança se não encontrado)
  Future<CategoryModel> getCategoryById(String id) async {
    final result = await getById(id);
    if (result == null) throw Exception('Categoria $id não encontrada');
    return result;
  }

  /// Alias de [create]
  Future<void> createCategory(CategoryModel category) async {
    await create(category.toJson());
  }

  /// Alias de [update]
  Future<void> updateCategory(String id, CategoryModel category) async {
    await update(id, category.toJson());
  }

  /// Alias de [delete]
  Future<void> deleteCategory(String id) async {
    await delete(id);
  }

  /// Alias de [toggleStatus] — lança se falhar
  Future<CategoryModel> toggleCategoryStatus(String id) async {
    final result = await toggleStatus(id);
    if (result == null)
      throw Exception('Falha ao alternar estado da categoria $id');
    return result;
  }

  /// Alias de [search]
  Future<List<CategoryModel>> searchCategories(String query) => search(query);
}
