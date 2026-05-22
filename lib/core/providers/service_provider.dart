// lib/core/providers/service_provider.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/domain/repositories/service_repository.dart';

class ServiceProvider extends ChangeNotifier {
  final ServiceRepository _repository =
      MockServiceRepository() as ServiceRepository;
  List<ServiceModel> _services = [];
  bool _isLoading = false;

  List<ServiceModel> get services => _services;
  bool get isLoading => _isLoading;

  Future<void> loadServices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _services = await _repository.getAllServices();
    } catch (e) {
      print('Erro ao carregar serviços: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addService(ServiceModel service) async {
    try {
      await _repository.createService(service);
      await loadServices();
    } catch (e) {
      print('Erro ao adicionar serviço: $e');
      rethrow;
    }
  }

  Future<void> updateService(String id, ServiceModel service) async {
    try {
      await _repository.updateService(id, service);
      await loadServices();
    } catch (e) {
      print('Erro ao atualizar serviço: $e');
      rethrow;
    }
  }

  Future<void> deleteService(String id) async {
    try {
      await _repository.deleteService(id);
      await loadServices();
    } catch (e) {
      print('Erro ao deletar serviço: $e');
      rethrow;
    }
  }

  // Métodos para clientes
  List<ServiceModel> getActiveServices() {
    return _services.where((s) => s.isAvailable).toList();
  }

  List<ServiceModel> getServicesByCategory(String categoryId) {
    return _services
        .where((s) => s.categoryId == categoryId && s.isAvailable)
        .toList();
  }
}

class MockServiceRepository {}
