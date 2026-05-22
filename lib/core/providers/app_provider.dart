// lib/core/providers/app_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/core/services/cache_service.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/data/models/location/location_model.dart';
import 'package:horaextra_app/data/models/location/route_info.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/data/models/user/user_model.dart';
import 'package:horaextra_app/data/models/request/service_request_model.dart';
import 'package:horaextra_app/data/models/provider/provider_model.dart';
import 'package:horaextra_app/data/models/provider/provider_selection_model.dart';
import 'package:latlong2/latlong.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService;
  final CacheService _cache = CacheService();

  bool _isInitialized = false;
  final Set<String> _loadingKeys = {};
  Timer? _pollingTimer;

  // Dados cacheados
  final Map<String, _CachedData<dynamic>> _localCache = {};
  
  // ✅ Controle de última busca para cache mais eficiente
  DateTime _lastPendingFetch = DateTime(2000);
  static const _cacheDuration = Duration(seconds: 3);

  List<CategoryModel> _categories = [];
  List<ServiceModel> _services = [];
  final Map<String, Uint8List> _imageCache = {};

  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  ThemeMode _themeMode = ThemeMode.light;
  UserModel? _currentUser;

  List<ServiceRequestModel> _pendingRequests = [];
  List<ServiceRequestModel> _activeServices = [];
  List<ServiceRequestModel> _clientRequests = [];
  List<ProviderModel> _nearbyProviders = [];
  int _unreadNotifications = 0;

  Map<String, dynamic> _providerStats = {
    'completedJobs': 0,
    'rating': 0.0,
    'reviewCount': 0,
    'responseRate': 100,
    'acceptanceRate': 100,
    'pendingRequests': 0,
    'activeServices': 0,
    'completedJobsCount': 0,
    'totalEarnings': 0,
  };

  AppProvider(this._apiService) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _cache.init();
    _isInitialized = true;
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    RealtimeWsService().pendingRequests.listen((requests) {
      if (requests.isNotEmpty) {
        _pendingRequests = requests
            .map((json) =>
                ServiceRequestModel.fromJson(json as Map<String, dynamic>))
            .toList();
        _providerStats['pendingRequests'] = _pendingRequests.length;
        notifyListeners();
      }
    });

    RealtimeWsService().serviceCompleted.listen((data) {
      final requestId = data['requestId']?.toString();
      if (requestId != null) {
        _updateRequestStatus(requestId, 'completed');
      }
    });
  }

  void _updateRequestStatus(String requestId, String newStatus) {
    for (var request in _pendingRequests) {
      if (request.id == requestId) {
        request.status = newStatus;
      }
    }
    for (var request in _activeServices) {
      if (request.id == requestId) {
        request.status = newStatus;
      }
    }
    for (var request in _clientRequests) {
      if (request.id == requestId) {
        request.status = newStatus;
      }
    }
    notifyListeners();
  }

  // Getters
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<ServiceModel> get services => List.unmodifiable(_services);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  ThemeMode get themeMode => _themeMode;
  UserModel? get currentUser => _currentUser;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  int get unreadNotifications => _unreadNotifications;
  List<ProviderModel> get nearbyProviders =>
      List.unmodifiable(_nearbyProviders);
  List<ServiceRequestModel> get pendingRequests =>
      List.unmodifiable(_pendingRequests);
  List<ServiceRequestModel> get clientRequests =>
      List.unmodifiable(_clientRequests);
  Map<String, dynamic> get providerStats => Map.unmodifiable(_providerStats);
  String get baseUrl => ApiConfig.baseUrl.replaceAll('/api', '');

  // Cache helpers
  Future<T?> _getCached<T>(String key,
      {Duration ttl = const Duration(minutes: 5)}) async {
    final cached = _localCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < ttl) {
      return cached.data as T?;
    }
    return null;
  }

  void _setCached<T>(String key, T data) {
    _localCache[key] = _CachedData(data, DateTime.now());
  }

  void _invalidateCache(String key) {
    _localCache.remove(key);
  }

  // Load methods
  Future<void> ensureInitialized() async {
    if (!_isInitialized) await _initialize();
  }

  Future<void> ensureCategoriesLoaded({bool forceRefresh = false}) async {
    await loadCategories(forceRefresh: forceRefresh);
  }

  Future<void> ensureServicesLoaded({bool forceRefresh = false}) async {
    await loadServices(forceRefresh: forceRefresh);
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (!_isInitialized) await _initialize();

    final cacheKey = '/categories';

    if (!forceRefresh) {
      final cached = await _getCached<List<CategoryModel>>(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _categories = cached;
        notifyListeners();
        return;
      }
    }

    if (_loadingKeys.contains(cacheKey)) return;
    _loadingKeys.add(cacheKey);
    _isLoading = true;
    notifyListeners();

    try {
      final data =
          await _apiService.getAuth('/categories', forceRefresh: forceRefresh);
      if (data is List) {
        _categories = data.map((json) => CategoryModel.fromJson(json)).toList();
        _setCached(cacheKey, _categories);
        await _cache.cacheData(
            cacheKey, _categories.map((c) => c.toJson()).toList());
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erro loadCategories: $e');
    } finally {
      _loadingKeys.remove(cacheKey);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadServices({bool forceRefresh = false}) async {
    if (!_isInitialized) await _initialize();

    final cacheKey = '/services';

    if (!forceRefresh) {
      final cached = await _getCached<List<ServiceModel>>(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _services = cached;
        notifyListeners();
        return;
      }
    }

    if (_loadingKeys.contains(cacheKey)) return;
    _loadingKeys.add(cacheKey);
    _isLoading = true;
    notifyListeners();

    try {
      final data =
          await _apiService.getAuth('/services', forceRefresh: forceRefresh);
      if (data is List) {
        _services = data.map((json) => ServiceModel.fromJson(json)).toList();
        _setCached(cacheKey, _services);
        await _cache.cacheData(
            cacheKey, _services.map((s) => s.toJson()).toList());
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erro loadServices: $e');
    } finally {
      _loadingKeys.remove(cacheKey);
      _isLoading = false;
      notifyListeners();
    }
  }

  List<CategoryModel> getActiveCategories() {
    return _categories.where((c) => c.isActive).toList();
  }

  List<ServiceModel> getActiveServices() {
    return _services.where((s) => s.isAvailable).toList();
  }

  List<ServiceModel> getServicesByCategory(String categoryId) {
    return _services
        .where((s) => s.categoryId == categoryId && s.isAvailable)
        .toList();
  }

  ServiceModel? getServiceById(String id) {
    try {
      return _services.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ServiceModel> searchServices(String query) {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    return _services
        .where((s) =>
            s.name.toLowerCase().contains(lower) ||
            s.description.toLowerCase().contains(lower))
        .toList();
  }

  // CRUD Categorias
  Future<bool> createCategory(CategoryModel result) async {
    try {
      final response = await _apiService.postAuth('/categories', {
        'name': result.name,
        'description': result.description,
        'icon': result.icon,
        'color': result.color,
        'order': result.order,
        'image_url': result.imageUrl,
        'is_active': result.isActive,
      });
      _categories.add(CategoryModel.fromJson(response));
      _invalidateCache('/categories');
      _successMessage = 'Categoria criada com sucesso!';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> updateCategory(String id, CategoryModel result) async {
    try {
      final response = await _apiService.putAuth('/categories/$id', {
        'name': result.name,
        'description': result.description,
        'icon': result.icon,
        'color': result.color,
        'order': result.order,
        'image_url': result.imageUrl,
        'is_active': result.isActive,
      });
      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) _categories[index] = CategoryModel.fromJson(response);
      _invalidateCache('/categories');
      _successMessage = 'Categoria atualizada com sucesso!';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await _apiService.deleteAuth('/categories/$id');
      _categories.removeWhere((c) => c.id == id);
      _invalidateCache('/categories');
      _successMessage = 'Categoria excluída com sucesso!';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> toggleCategoryStatus(String id) async {
    try {
      final response =
          await _apiService.patchAuth('/categories/$id/toggle', {});
      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        if (response['id'] != null) {
          _categories[index] = CategoryModel.fromJson(response);
        } else {
          _categories[index] = _categories[index].copyWith(
            isActive: !_categories[index].isActive,
          );
        }
      }
      _invalidateCache('/categories');
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // CRUD Serviços
  Future<bool> createService(ServiceModel result) async {
    try {
      final response = await _apiService.postAuth('/services', {
        'name': result.name,
        'description': result.description,
        'price': result.price,
        'category_id': result.categoryId,
        'estimated_time': result.estimatedTime,
        'is_available': result.isAvailable,
      });
      _services.add(ServiceModel.fromJson(response));
      _invalidateCache('/services');
      _successMessage = 'Serviço criado com sucesso!';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> updateService(String id, ServiceModel result) async {
    try {
      final response = await _apiService.putAuth('/services/$id', {
        'name': result.name,
        'description': result.description,
        'price': result.price,
        'category_id': result.categoryId,
        'estimated_time': result.estimatedTime,
        'is_available': result.isAvailable,
      });
      final index = _services.indexWhere((s) => s.id == id);
      if (index != -1) _services[index] = ServiceModel.fromJson(response);
      _invalidateCache('/services');
      _successMessage = 'Serviço atualizado com sucesso!';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    try {
      await _apiService.deleteAuth('/services/$id');
      _services.removeWhere((s) => s.id == id);
      _invalidateCache('/services');
      _successMessage = 'Serviço excluído com sucesso!';
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> toggleServiceStatus(String id) async {
    try {
      final service = getServiceById(id);
      if (service == null) return false;
      final response = await _apiService.patchAuth('/services/$id/toggle', {});
      final index = _services.indexWhere((s) => s.id == id);
      if (index != -1) {
        if (response['id'] != null) {
          _services[index] = ServiceModel.fromJson(response);
        } else {
          _services[index] = service.copyWith(
            isAvailable: !service.isAvailable,
          );
        }
      }
      _invalidateCache('/services');
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // Prestadores próximos
  Future<List<ProviderModel>> getProvidersNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'providers_nearby_${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}_$radiusKm';

    if (!forceRefresh) {
      final cached = await _getCached<List<ProviderModel>>(cacheKey,
          ttl: const Duration(seconds: 30));
      if (cached != null) {
        return cached;
      }
    }

    try {
      debugPrint('📍 Buscando prestadores próximos...');
      final response = await _apiService.getAuth(
        '/providers/nearby?lat=$latitude&lng=$longitude&maxDistance=$radiusKm',
        forceRefresh: forceRefresh,
      );

      if (response is List) {
        _nearbyProviders =
            response.map((json) => ProviderModel.fromJson(json)).toList();
        _setCached(cacheKey, _nearbyProviders);
        debugPrint('✅ ${_nearbyProviders.length} prestadores encontrados');
        notifyListeners();
        return _nearbyProviders;
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar prestadores: $e');
    }
    return [];
  }

  Future<List<ProviderSelectionModel>> findNearbyProviders({
    required String serviceId,
    required double clientLatitude,
    required double clientLongitude,
    double maxDistance = 20,
  }) async {
    final providers = await getProvidersNearby(
      latitude: clientLatitude,
      longitude: clientLongitude,
      radiusKm: maxDistance,
    );
    return providers
        .map((p) => ProviderSelectionModel(
              id: p.id,
              name: p.name,
              photoUrl: p.photoUrl ?? '',
              rating: p.rating,
              reviewCount: p.completedJobs,
              distance: p.distance,
              price: p.price,
              specialties: p.specialties,
              completedJobs: p.completedJobs,
              responseRate: 95,
              acceptanceRate: 90,
              isAvailable: p.isOnline,
              matchScore: p.rating * 10,
              isOnline: p.isOnline,
              latitude: p.latitude,
              longitude: p.longitude,
              isSelected: false,
            ))
        .toList();
  }

  // Solicitações do Prestador
  Future<void> loadProviderStats() async {
    try {
      final response =
          await _apiService.getAuth('/providers/me/stats', forceRefresh: true);
      if (response is Map) {
        _providerStats = {
          ..._providerStats,
          ...Map<String, dynamic>.from(response),
        };
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar stats: $e');
    }
  }

  Map<String, dynamic> getProviderStats() => _providerStats;

  List<Map<String, dynamic>> getPendingRequests() {
    return _pendingRequests.map((r) => r.toJson()).toList();
  }

  void setPendingRequestsFromWs(List<dynamic> requests) {
    try {
      final newRequests = requests
          .map((json) =>
              ServiceRequestModel.fromJson(json as Map<String, dynamic>))
          .toList();

      _pendingRequests = newRequests;
      _providerStats['pendingRequests'] = _pendingRequests.length;
      notifyListeners();
      debugPrint(
          '📦 ${_pendingRequests.length} pedidos pendentes carregados via WS');
    } catch (e) {
      debugPrint('❌ Erro ao processar pedidos pendentes via WS: $e');
    }
  }

  List<ServiceRequestModel> getPendingRequestsList() => _pendingRequests;

  Future<List<ServiceRequestModel>> getProviderPendingRequests({
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'provider_pending_${_currentUser?.id}';

    // ✅ Cache controlado por tempo (3 segundos)
    if (!forceRefresh) {
      final now = DateTime.now();
      if (now.difference(_lastPendingFetch) < _cacheDuration) {
        debugPrint('⚡ Cache de pedidos pendentes (recente) - ${_pendingRequests.length} pedidos');
        return _pendingRequests;
      }
    }

    try {
      debugPrint('📡 Buscando pedidos pendentes da API (forceRefresh=$forceRefresh)');
      final response = await _apiService.getAuth(
        '/requests/provider/pending',
        forceRefresh: forceRefresh,
      );

      if (response is List) {
        _pendingRequests =
            response.map((json) => ServiceRequestModel.fromJson(json)).toList();
        _providerStats['pendingRequests'] = _pendingRequests.length;
        _setCached(cacheKey, _pendingRequests);
        _lastPendingFetch = DateTime.now();
        notifyListeners();
        debugPrint(
            '📦 ${_pendingRequests.length} pedidos pendentes carregados');
        return _pendingRequests;
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar solicitações pendentes: $e');
    }
    return [];
  }

  Future<List<ServiceRequestModel>> getProviderActiveServices() async {
    try {
      final response = await _apiService.getAuth('/requests/provider/active',
          forceRefresh: true);
      if (response is List) {
        _activeServices =
            response.map((json) => ServiceRequestModel.fromJson(json)).toList();
        notifyListeners();
        return _activeServices;
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar serviços ativos: $e');
    }
    return [];
  }

  Future<void> acceptRequest(String requestId) async {
    debugPrint('📡 Aceitando pedido: $requestId');
    try {
      await _apiService.patchAuth('/requests/$requestId/accept', {});

      // ✅ Remover da lista local IMEDIATAMENTE
      _pendingRequests.removeWhere((r) => r.id == requestId);
      _providerStats['pendingRequests'] = _pendingRequests.length;

      // ✅ Forçar refresh TOTAL (ignorar todos os caches)
      _lastPendingFetch = DateTime(2000);
      _invalidateCache('provider_pending_${_currentUser?.id}');
      
      notifyListeners();

      // Buscar dados atualizados em background
      unawaited(getProviderPendingRequests(forceRefresh: true));
      unawaited(loadProviderStats());

      debugPrint('✅ Pedido $requestId aceito com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao aceitar pedido: $e');
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId) async {
    debugPrint('📡 Recusando pedido: $requestId');
    try {
      await _apiService.patchAuth('/requests/$requestId/reject', {});
      
      // ✅ Remover da lista local IMEDIATAMENTE
      _pendingRequests.removeWhere((r) => r.id == requestId);
      _providerStats['pendingRequests'] = _pendingRequests.length;
      
      // ✅ Forçar refresh TOTAL
      _lastPendingFetch = DateTime(2000);
      _invalidateCache('provider_pending_${_currentUser?.id}');
      
      notifyListeners();
      
      unawaited(getProviderPendingRequests(forceRefresh: true));
      unawaited(loadProviderStats());
      
      debugPrint('❌ Pedido $requestId recusado');
    } catch (e) {
      debugPrint('❌ Erro ao recusar pedido: $e');
      rethrow;
    }
  }

  Future<void> completeService(String requestId) async {
    debugPrint('📡 Cliente concluindo serviço: $requestId');
    try {
      await _apiService.patchAuth('/requests/$requestId/complete', {});
      _updateRequestStatus(requestId, 'completed');
      _invalidateCache('client_requests_${_currentUser?.id}');
      _invalidateCache('provider_pending_${_currentUser?.id}');
      _lastPendingFetch = DateTime(2000);
      await loadClientRequests(forceRefresh: true);
      await loadProviderStats();
      RealtimeWsService().notifyServiceCompleted(requestId);
      debugPrint('✅ Serviço $requestId concluído pelo cliente');
    } catch (e) {
      debugPrint('❌ Erro ao concluir serviço: $e');
      rethrow;
    }
  }

  Future<void> startService(String requestId) async {
    debugPrint('🚀 Prestador iniciando serviço: $requestId');
    try {
      await _apiService.patchAuth('/requests/$requestId/start', {});
      await getProviderActiveServices();
      debugPrint('✅ Serviço $requestId iniciado pelo prestador');
    } catch (e) {
      debugPrint('❌ Erro ao iniciar serviço: $e');
      rethrow;
    }
  }

  Future<void> updateProviderStatus(bool isOnline) async {
    try {
      await _apiService
          .patchAuth('/providers/availability', {'is_available': isOnline});
      RealtimeWsService().setOnlineStatus(isOnline);
    } catch (e) {
      debugPrint('❌ Erro ao atualizar status: $e');
    }
  }

  // Solicitações do Cliente
  List<ServiceRequestModel> getClientRequestsList() => _clientRequests;

  Future<void> loadClientRequests({bool forceRefresh = false}) async {
    final cacheKey = 'client_requests_${_currentUser?.id}';

    if (!forceRefresh) {
      final cached = await _getCached<List<ServiceRequestModel>>(cacheKey,
          ttl: const Duration(seconds: 15));
      if (cached != null) {
        _clientRequests = cached;
        notifyListeners();
        return;
      }
    }

    try {
      final response = await _apiService.getAuth('/requests/client',
          forceRefresh: forceRefresh);
      if (response is List) {
        _clientRequests =
            response.map((json) => ServiceRequestModel.fromJson(json)).toList();
        _setCached(cacheKey, _clientRequests);
        notifyListeners();
        debugPrint(
            '📦 ${_clientRequests.length} solicitações do cliente carregadas');
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar solicitações do cliente: $e');
    }
  }

  Future<String?> createRequest({
    required String serviceId,
    required String clientId,
    required String clientName,
    required List<String> providerIds,
    required LocationModel location,
    double? budget,
    DateTime? scheduledDate,
    String? observations,
  }) async {
    try {
      final response = await _apiService.postAuth('/requests', {
        'service_id': serviceId,
        'client_id': clientId,
        'client_name': clientName,
        'selected_providers': providerIds,
        'location': location.toJson(),
        'budget': budget,
        'scheduled_date': scheduledDate?.toIso8601String(),
        'observations': observations,
      });
      final requestId = response['id']?.toString() ?? '';
      _unreadNotifications += providerIds.length;
      notifyListeners();
      return requestId;
    } catch (e) {
      _error = 'Erro ao criar solicitação: $e';
      return null;
    }
  }

  // Rotas
  Future<RouteInfo?> calculateRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final cacheKey =
        'route_${from.latitude.toStringAsFixed(4)}_${from.longitude.toStringAsFixed(4)}_${to.latitude.toStringAsFixed(4)}_${to.longitude.toStringAsFixed(4)}';

    final cached =
        await _getCached<RouteInfo>(cacheKey, ttl: const Duration(minutes: 10));
    if (cached != null) return cached;

    try {
      // CORRIGIDO: Remover /api extra da URL
      final url =
          '${ApiConfig.baseUrl}/route?fromLat=${from.latitude}&fromLng=${from.longitude}&toLat=${to.latitude}&toLng=${to.longitude}';
      debugPrint('📍 Calculando rota: $url');

      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pts = (data['points'] as List)
            .map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList();
        final route = RouteInfo(
          distanceKm: (data['distanceKm'] as num).toDouble(),
          durationMin: (data['durationMin'] as num).toDouble(),
          points: pts,
          polyline: '',
        );
        _setCached(cacheKey, route);
        return route;
      }
    } catch (e) {
      debugPrint('❌ calculateRoute: $e');
    }

    // Fallback
    final dist = _haversine(from, to);
    final route = RouteInfo(
      distanceKm: dist,
      durationMin: dist * 4,
      points: _straightLine(from, to),
      polyline: '',
    );
    _setCached(cacheKey, route);
    return route;
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.pow(math.sin(dLon / 2), 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  List<LatLng> _straightLine(LatLng from, LatLng to) => List.generate(
        21,
        (i) => LatLng(
          from.latitude + (to.latitude - from.latitude) * i / 20,
          from.longitude + (to.longitude - from.longitude) * i / 20,
        ),
      );

  // Admin
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _apiService.getAuth('/admin/users');
      if (response is Map && response['data'] is List) {
        return (response['data'] as List)
            .map((json) => UserModel.fromJson(json))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar utilizadores: $e');
    }
    return [];
  }

  Future<void> approveProvider(String id) async {
    await _apiService.postAuth('/admin/providers/$id/approve', {});
  }

  Future<void> rejectProvider(String id) async {
    await _apiService.postAuth('/admin/providers/$id/reject', {});
  }

  Map<String, dynamic> getAdminStats() {
    return {
      'totalUsers': _categories.length + _services.length,
      'totalProviders': _nearbyProviders.length,
      'totalServices': _services.length,
      'totalCategories': _categories.length,
      'totalRequests': _pendingRequests.length + _clientRequests.length,
      'newUsers': 0,
      'todayRequests': 0,
    };
  }

  Future<void> loadAdminStats() async {}

  // Utilizador
  void setCurrentUser(UserModel user) {
    _currentUser = user;
    _localCache.clear();
    _lastPendingFetch = DateTime(2000);
    notifyListeners();

    Future.wait([
      loadCategories(),
      loadServices(),
      if (user.role.toString().contains('provider')) ...[
        loadProviderStats(),
        getProviderPendingRequests(forceRefresh: true),
      ] else if (user.role.toString().contains('client')) ...[
        loadClientRequests(forceRefresh: true),
      ],
    ]);
  }

  void logout() {
    _pollingTimer?.cancel();
    _currentUser = null;
    _categories = [];
    _services = [];
    _clientRequests = [];
    _pendingRequests = [];
    _nearbyProviders = [];
    _unreadNotifications = 0;
    _localCache.clear();
    _loadingKeys.clear();
    _lastPendingFetch = DateTime(2000);
    _cache.clear();
    _apiService.clearAllCache();
    RealtimeWsService().disconnect();
    notifyListeners();
  }

  void toggleDarkMode() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  void markNotificationsAsRead() {
    _unreadNotifications = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

class _CachedData<T> {
  final T data;
  final DateTime timestamp;

  _CachedData(this.data, this.timestamp);
}