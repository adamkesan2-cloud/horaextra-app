// lib/domain/repositories/service_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';

class ServiceRepository {
  final ApiService _apiService;

  ServiceRepository(this._apiService);

  String _url(String path) => '${ApiConfig.baseUrl}$path';

  Future<String?> _token() async => await _apiService.authProvider?.getToken();

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Métodos principais ────────────────────────────────────────────────────

  Future<List<ServiceModel>> getAll({bool activeOnly = true}) async {
    try {
      final token = await _token();
      final path = activeOnly ? '/services' : '/services/admin';
      final res = await http
          .get(Uri.parse(_url(path)), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.map((j) => ServiceModel.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('❌ getAll services: $e');
    }
    return [];
  }

  Future<ServiceModel?> getById(String id) async {
    try {
      final token = await _token();
      final res = await http
          .get(Uri.parse(_url('/services/$id')), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return ServiceModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('❌ getById service: $e');
    }
    return null;
  }

  Future<List<ServiceModel>> getByCategory(String categoryId) async {
    try {
      final token = await _token();
      final res = await http
          .get(Uri.parse(_url('/categories/$categoryId/services')),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.map((j) => ServiceModel.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint('❌ getByCategory service: $e');
    }
    return [];
  }

  Future<ServiceModel?> create(Map<String, dynamic> data) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .post(Uri.parse(_url('/services')),
              headers: _headers(token), body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 201) {
        return ServiceModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('❌ create service: $e');
    }
    return null;
  }

  Future<ServiceModel?> update(String id, Map<String, dynamic> data) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .put(Uri.parse(_url('/services/$id')),
              headers: _headers(token), body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return ServiceModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('❌ update service: $e');
    }
    return null;
  }

  Future<bool> delete(String id) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .delete(Uri.parse(_url('/services/$id')), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('❌ delete service: $e');
      return false;
    }
  }

  Future<ServiceModel?> toggleStatus(String id) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Não autenticado');
      final res = await http
          .patch(Uri.parse(_url('/services/$id/toggle')),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return ServiceModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('❌ toggleStatus service: $e');
    }
    return null;
  }

  Future<List<ServiceModel>> search(String query) async {
    final all = await getAll();
    final lower = query.toLowerCase();
    return all
        .where((s) =>
            s.name.toLowerCase().contains(lower) ||
            s.description.toLowerCase().contains(lower))
        .toList();
  }

  // ── Aliases para use cases / providers existentes ─────────────────────────
  // Mantêm compatibilidade sem alterar os ficheiros que os chamam.

  /// Alias de [getAll]
  Future<List<ServiceModel>> getAllServices() => getAll();

  /// Alias de [getById] — lança se não encontrado
  Future<ServiceModel> getServiceById(String id) async {
    final result = await getById(id);
    if (result == null) throw Exception('Serviço $id não encontrado');
    return result;
  }

  /// Alias de [getByCategory]
  Future<List<ServiceModel>> getServicesByCategory(String categoryId) =>
      getByCategory(categoryId);

  /// Alias de [create]
  Future<void> createService(ServiceModel service) async {
    await create(service.toJson());
  }

  /// Alias de [update]
  Future<void> updateService(String id, ServiceModel service) async {
    await update(id, service.toJson());
  }

  /// Alias de [delete]
  Future<void> deleteService(String id) async {
    await delete(id);
  }

  /// Alias de [toggleStatus] — lança se falhar
  Future<ServiceModel> toggleServiceStatus(String id) async {
    final result = await toggleStatus(id);
    if (result == null)
      throw Exception('Falha ao alternar estado do serviço $id');
    return result;
  }

  /// Alias de [search]
  Future<List<ServiceModel>> searchServices(String query) => search(query);
}
