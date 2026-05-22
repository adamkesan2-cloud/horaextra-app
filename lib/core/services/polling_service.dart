// lib/core/services/polling_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/core/services/api_service.dart';

class PollingService {
  static final PollingService _instance = PollingService._internal();
  factory PollingService() => _instance;
  PollingService._internal();

  Timer? _pollingTimer;
  bool _isPolling = false;
  String? _lastRole;
  String? _lastUserId;

  // Streams para notificações via polling
  final _newRequestsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _requestResponsesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _pendingRequestsController =
      StreamController<List<dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get newRequests => _newRequestsController.stream;
  Stream<Map<String, dynamic>> get requestResponses =>
      _requestResponsesController.stream;
  Stream<List<dynamic>> get pendingRequests =>
      _pendingRequestsController.stream;

  // Cache de último estado para detectar mudanças
  Set<String> _lastRequestIds = {};
  Map<String, String> _lastRequestStatuses = {};

  void startPolling({required String role, required String userId}) {
    if (_isPolling) return;

    _lastRole = role;
    _lastUserId = userId;
    _isPolling = true;

    debugPrint('📡 Iniciando polling para $role (a cada 3 segundos)');

    // Polling inicial imediato
    _poll();

    // Polling periódico
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!_isPolling) return;

    try {
      if (_lastRole == 'provider') {
        await _pollProviderRequests();
      } else if (_lastRole == 'client') {
        await _pollClientResponses();
      }
    } catch (e) {
      debugPrint('❌ Polling error: $e');
    }
  }

  Future<void> _pollProviderRequests() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getAuth(
        ApiConfig.providerPendingRequests,
        forceRefresh: true,
      );

      if (response is List) {
        final currentRequestIds = <String>{};
        final currentStatuses = <String, String>{};

        for (final req in response) {
          final id = req['id']?.toString();
          if (id != null) {
            currentRequestIds.add(id);
            currentStatuses[id] = req['status']?.toString() ?? 'pending';
          }
        }

        // Detectar NOVOS pedidos
        for (final req in response) {
          final id = req['id']?.toString();
          if (id != null && !_lastRequestIds.contains(id)) {
            debugPrint('🆕 Polling: NOVO PEDIDO DETECTADO! $id');
            _newRequestsController.add(Map<String, dynamic>.from(req));
          }
        }

        // Detectar mudanças de status (aceites/recusados)
        for (final entry in _lastRequestStatuses.entries) {
          final currentStatus = currentStatuses[entry.key];
          if (currentStatus != null && currentStatus != entry.value) {
            debugPrint(
                '📊 Polling: Status do pedido ${entry.key} mudou: ${entry.value} → $currentStatus');

            if (currentStatus == 'accepted') {
              _requestResponsesController.add({
                'requestId': entry.key,
                'accepted': true,
                'providerName': 'Prestador',
              });
            } else if (currentStatus == 'cancelled') {
              _requestResponsesController.add({
                'requestId': entry.key,
                'accepted': false,
              });
            }
          }
        }

        _lastRequestIds = currentRequestIds;
        _lastRequestStatuses = currentStatuses;
        _pendingRequestsController.add(response);
      }
    } catch (e) {
      debugPrint('❌ Polling provider requests error: $e');
    }
  }

  Future<void> _pollClientResponses() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getAuth(
        ApiConfig.clientRequests,
        forceRefresh: true,
      );

      if (response is List) {
        for (final req in response) {
          final id = req['id']?.toString();
          final status = req['status']?.toString();

          if (id != null && status != null) {
            final lastStatus = _lastRequestStatuses[id];

            if (lastStatus != status) {
              debugPrint(
                  '📊 Polling: Pedido $id mudou status: $lastStatus → $status');

              if (status == 'accepted') {
                _requestResponsesController.add({
                  'requestId': id,
                  'accepted': true,
                  'providerName': req['provider']?['name'] ?? 'Prestador',
                });
              } else if (status == 'cancelled' && lastStatus == 'pending') {
                _requestResponsesController.add({
                  'requestId': id,
                  'accepted': false,
                });
              } else if (status == 'completed') {
                _requestResponsesController.add({
                  'requestId': id,
                  'completed': true,
                });
              }
            }
          }

          _lastRequestStatuses[id!] = status!;
        }
      }
    } catch (e) {
      debugPrint('❌ Polling client responses error: $e');
    }
  }

  void stopPolling() {
    _isPolling = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastRequestIds.clear();
    _lastRequestStatuses.clear();
    debugPrint('📡 Polling parado');
  }

  void dispose() {
    stopPolling();
    _newRequestsController.close();
    _requestResponsesController.close();
    _pendingRequestsController.close();
  }
}
