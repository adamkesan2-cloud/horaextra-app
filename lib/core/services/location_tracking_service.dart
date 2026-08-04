// lib/core/services/location_tracking_service.dart
//
// Serviço singleton que envia a localização do prestador via WebSocket
// de forma contínua, INDEPENDENTE do ecrã que está aberto.
//
// Deve ser iniciado uma vez quando o prestador fica "online" (login ou
// toggle manual) e só deve ser parado quando ele fica "offline" ou faz
// logout — nunca ao sair de um ecrã específico (ex: ao sair do mapa).

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/data/models/service/location_service.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  Timer? _timer;
  bool _tracking = false;

  bool get isTracking => _tracking;

  /// Inicia o envio periódico de localização via WS.
  /// Chamar isto quando o prestador fica online (login, toggle, etc.) —
  /// não em initState de um ecrã específico, para não parar quando ele
  /// navega para outro lado da app.
  void start({Duration interval = const Duration(seconds: 5)}) {
    if (_tracking) return; // já a correr, evita duplicar
    _tracking = true;
    debugPrint('📍 LocationTrackingService: iniciado (${interval.inSeconds}s)');

    _tick(); // leitura imediata
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (!_tracking) return;
    try {
      final pos = await LocationService.getCurrentPosition();
      RealtimeWsService().sendLocation(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('❌ LocationTrackingService: erro ao obter posição: $e');
    }
  }

  /// Parar só deve acontecer quando o prestador fica offline ou faz logout.
  void stop() {
    if (!_tracking) return;
    _tracking = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('📍 LocationTrackingService: parado');
  }
}