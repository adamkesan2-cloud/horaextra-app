// lib/core/services/realtime_ws_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:horaextra_app/core/config/api_config.dart';

class RealtimeWsService {
  static final RealtimeWsService _i = RealtimeWsService._();
  factory RealtimeWsService() => _i;
  RealtimeWsService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _registered = false;
  bool _isConnecting = false;

  String? _userId;
  String? _name;
  String? _role;
  double _lat = -25.9692;
  double _lng = 32.5732;
  bool _isOnline = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  final _connectionStatus = StreamController<bool>.broadcast();
  final _providerLocations = StreamController<Map<String, dynamic>>.broadcast();
  final _providerOnline = StreamController<Map<String, dynamic>>.broadcast();
  final _providerOffline = StreamController<Map<String, dynamic>>.broadcast();
  final _newRequest = StreamController<Map<String, dynamic>>.broadcast();
  final _requestResponse = StreamController<Map<String, dynamic>>.broadcast();
  final _serviceCompleted = StreamController<Map<String, dynamic>>.broadcast();
  final _providerSnapshot = StreamController<List<dynamic>>.broadcast();
  final _pendingRequests = StreamController<List<dynamic>>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatus.stream;
  Stream<Map<String, dynamic>> get providerLocations =>
      _providerLocations.stream;
  Stream<Map<String, dynamic>> get providerOnline => _providerOnline.stream;
  Stream<Map<String, dynamic>> get providerOffline => _providerOffline.stream;
  Stream<Map<String, dynamic>> get newRequest => _newRequest.stream;
  Stream<Map<String, dynamic>> get requestResponse => _requestResponse.stream;
  Stream<Map<String, dynamic>> get serviceCompleted => _serviceCompleted.stream;
  Stream<List<dynamic>> get providerSnapshot => _providerSnapshot.stream;
  Stream<List<dynamic>> get pendingRequests => _pendingRequests.stream;

  bool get isConnected => _registered && _channel != null;

  // ── Envio interno — usa _channel diretamente, sem verificar _registered ──
  void _sendRaw(Map<String, dynamic> data) {
    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('❌ WS: erro ao enviar: $e');
      _onDisconnect();
    }
  }

  // ── Envio público — verifica se está registado ────────────────────────────
  void _send(Map<String, dynamic> data) {
    if (!_registered || _channel == null) {
      debugPrint('⚠️ WS: mensagem não enviada (desconectado): ${data['type']}');
      return;
    }
    _sendRaw(data);
  }

  Future<void> connect({
    required String userId,
    required String name,
    required String role,
    double lat = -25.9692,
    double lng = 32.5732,
    bool isOnline = true,
  }) async {
    if (_registered && _userId == userId && _channel != null) {
      debugPrint('🔌 WS: já conectado como $_userId');
      return;
    }

    if (_isConnecting) {
      debugPrint('🔌 WS: já conectando, aguarde...');
      return;
    }

    if (_registered) await disconnect();

    _isConnecting = true;
    _userId = userId;
    _name = name;
    _role = role;
    _lat = lat;
    _lng = lng;
    _isOnline = isOnline;
    _reconnectAttempts = 0;

    try {
      final uri = Uri.parse(ApiConfig.wsUrl);
      debugPrint('🔌 WS: conectando a $uri como $name ($role)');

      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Timeout de conexão WS'),
      );

      _sub = _channel!.stream.listen(
        (data) => _onMessage(data.toString()),
        onError: (e) {
          debugPrint('🔌 WS: erro na stream: $e');
          _onDisconnect();
        },
        onDone: _onDisconnect,
        cancelOnError: false,
      );

      _isConnecting = false;
      debugPrint('🔌 WS: conectado como $name ($role)');

      // Enviar register diretamente — _registered ainda é false aqui
      _sendRaw({
        'type': 'register',
        'userId': userId,
        'name': name,
        'role': role,
        'lat': lat,
        'lng': lng,
        'isOnline': isOnline,
      });

      // Ping periódico para manter conexão viva
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_channel != null) {
          _sendRaw({'type': 'ping'});
        }
      });
    } catch (e) {
      debugPrint('🔌 WS: falha na conexão: $e');
      _isConnecting = false;
      _registered = false;
      _connectionStatus.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('🔌 WS: máximo de tentativas de reconexão atingido');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds:
          math.min(_reconnectDelay.inSeconds * (_reconnectAttempts + 1), 30),
    );
    _reconnectTimer = Timer(delay, () {
      if (!_registered && _userId != null) {
        _reconnectAttempts++;
        debugPrint(
            '🔌 WS: reconectando ($_reconnectAttempts/$_maxReconnectAttempts)');
        connect(
          userId: _userId!,
          name: _name ?? '',
          role: _role ?? 'client',
          lat: _lat,
          lng: _lng,
          isOnline: _isOnline,
        );
      }
    });
  }

  void _onDisconnect() {
    debugPrint('🔌 WS: desconectado');
    _registered = false;
    _channel = null;
    _sub = null;
    _pingTimer?.cancel();
    _connectionStatus.add(false);
    _scheduleReconnect();
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _registered = false;
    _isConnecting = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (e) {
      debugPrint('🔌 WS: erro ao fechar conexão: $e');
    }
    _channel = null;
    _connectionStatus.add(false);
    debugPrint('🔌 WS: desconexão manual');
  }

  void sendLocation(double lat, double lng) {
    _lat = lat;
    _lng = lng;
    _send({'type': 'location_update', 'lat': lat, 'lng': lng});
  }

  void setOnlineStatus(bool online) {
    _isOnline = online;
    _send({'type': 'set_online_status', 'isOnline': online});
  }

  void sendServiceRequest({
    required String requestId,
    required List<String> selectedProviderIds,
    required String serviceName,
    required String clientName,
    required Map<String, dynamic> location,
  }) {
    debugPrint(
        '📤 WS: pedido $requestId → ${selectedProviderIds.length} prestador(es)');
    _send({
      'type': 'service_request',
      'requestId': requestId,
      'selectedProviderIds': selectedProviderIds,
      'serviceName': serviceName,
      'clientName': clientName,
      'location': location,
    });
  }

  void respondToRequest(String requestId, bool accepted) {
    debugPrint(
        '📤 WS: ${accepted ? "aceitando" : "recusando"} pedido $requestId');
    _send({
      'type': 'request_response',
      'requestId': requestId,
      'accepted': accepted,
    });
  }

  void notifyServiceCompleted(String requestId) {
    debugPrint('📤 WS: serviço $requestId concluído');
    _send({'type': 'service_completed', 'requestId': requestId});
  }

  void _onMessage(String raw) {
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      debugPrint('📨 WS recv: $type');

      switch (type) {
        case 'registered':
          _registered = true;
          debugPrint('✅ WS: registo confirmado para $_userId');
          _connectionStatus.add(true);
          break;

        case 'providers_snapshot':
          final providers = msg['providers'] as List<dynamic>? ?? [];
          _providerSnapshot.add(providers);
          break;

        case 'pending_requests':
          final requests = msg['requests'] as List<dynamic>? ?? [];
          _pendingRequests.add(requests);
          break;

        case 'NEW_REQUEST':
          debugPrint('🆕 WS: NOVA SOLICITAÇÃO ${msg['requestId']}');
          _newRequest.add(msg);
          break;

        case 'REQUEST_ACCEPTED':
          _requestResponse.add({...msg, 'accepted': true});
          break;

        case 'REQUEST_REJECTED':
          _requestResponse.add({...msg, 'accepted': false});
          break;

        case 'REQUEST_ACCEPTED_CONFIRM':
          _requestResponse.add({...msg, 'accepted': true, 'confirmed': true});
          break;

        case 'REQUEST_REJECTED_CONFIRM':
          _requestResponse.add({...msg, 'accepted': false, 'confirmed': true});
          break;

        case 'SERVICE_COMPLETED':
          _serviceCompleted.add(msg);
          _requestResponse.add({...msg, 'completed': true, 'accepted': true});
          break;

        case 'SERVICE_COMPLETED_ACK':
          _serviceCompleted.add(msg);
          _requestResponse.add({...msg, 'completed': true});
          break;

        case 'provider_location':
          final providerId = msg['providerId']?.toString();
          final lat = msg['lat'] as num?;
          final lng = msg['lng'] as num?;
          if (providerId != null && lat != null && lng != null) {
            _providerLocations.add(msg);
          }
          break;

        case 'provider_online':
          final p = msg['provider'];
          if (p is Map<String, dynamic>) _providerOnline.add(p);
          break;

        case 'provider_offline':
          final p = msg['provider'];
          if (p is Map<String, dynamic>) _providerOffline.add(p);
          break;

        case 'ping':
          _sendRaw({'type': 'pong'});
          break;

        case 'pong':
        case 'heartbeat_ack':
          break;

        default:
          debugPrint('⚠️ WS: tipo desconhecido → $type');
          if (msg.containsKey('accepted')) {
            _requestResponse.add(msg);
          } else if (msg.containsKey('requestId') &&
              msg.containsKey('serviceName')) {
            _newRequest.add(msg);
          }
      }
    } catch (e) {
      debugPrint('❌ WS: erro ao processar mensagem: $e');
    }
  }

  void dispose() {
    debugPrint('🔌 WS: disposing service');
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _registered = false;
    _isConnecting = false;
    _userId = null;
    _connectionStatus.close();
    _providerLocations.close();
    _providerOnline.close();
    _providerOffline.close();
    _newRequest.close();
    _requestResponse.close();
    _serviceCompleted.close();
    _providerSnapshot.close();
    _pendingRequests.close();
  }
}
