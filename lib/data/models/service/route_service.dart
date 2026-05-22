// lib/core/services/route_service.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:horaextra_app/data/models/location/route_info.dart';
import 'package:horaextra_app/core/services/api_service.dart';

class RouteService {
  final ApiService _apiService;

  RouteService(this._apiService);

  Future<RouteInfo?> calculateRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    try {
      final response = await _apiService.postAuth('/routes/calculate', {
        'origin': {'lat': from.latitude, 'lng': from.longitude},
        'destination': {'lat': to.latitude, 'lng': to.longitude},
      });

      if (response != null && response is Map) {
        return RouteInfo.fromJson(response.cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('❌ Erro ao calcular rota: $e');
    }
    return null;
  }
}
