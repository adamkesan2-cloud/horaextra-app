// lib/data/models/service/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static const LatLng maputoCenter = LatLng(-25.9692, 32.5732);

  // Mapa de bairros de Maputo com coordenadas aproximadas
  static final Map<String, List<LatLngBounds>> _neighborhoodBounds = {
    'Intaka': [
      LatLngBounds(
        const LatLng(-25.9580, 32.5880),
        const LatLng(-25.9520, 32.5980),
      ),
    ],
    'Primeira Rotunda': [
      LatLngBounds(
        const LatLng(-25.9620, 32.5900),
        const LatLng(-25.9550, 32.6000),
      ),
    ],
    'Sommerschield': [
      LatLngBounds(
        const LatLng(-25.9600, 32.5780),
        const LatLng(-25.9500, 32.5900),
      ),
    ],
    'Polana': [
      LatLngBounds(
        const LatLng(-25.9750, 32.5650),
        const LatLng(-25.9600, 32.5800),
      ),
    ],
    'Central': [
      LatLngBounds(
        const LatLng(-25.9750, 32.5750),
        const LatLng(-25.9650, 32.5880),
      ),
    ],
    'Coop': [
      LatLngBounds(
        const LatLng(-25.9550, 32.5550),
        const LatLng(-25.9450, 32.5650),
      ),
    ],
    'Malhangalene': [
      LatLngBounds(
        const LatLng(-25.9700, 32.5550),
        const LatLng(-25.9600, 32.5650),
      ),
    ],
    'Jardim': [
      LatLngBounds(
        const LatLng(-25.9850, 32.5750),
        const LatLng(-25.9750, 32.5880),
      ),
    ],
    'Mafalala': [
      LatLngBounds(
        const LatLng(-25.9550, 32.6000),
        const LatLng(-25.9400, 32.6150),
      ),
    ],
    'Costa do Sol': [
      LatLngBounds(
        const LatLng(-25.9700, 32.6200),
        const LatLng(-25.9500, 32.6400),
      ),
    ],
    'Triunfo': [
      LatLngBounds(
        const LatLng(-25.9400, 32.5550),
        const LatLng(-25.9300, 32.5650),
      ),
    ],
    'Ferroviário': [
      LatLngBounds(
        const LatLng(-25.9750, 32.6100),
        const LatLng(-25.9650, 32.6250),
      ),
    ],
    'Maxaquene': [
      LatLngBounds(
        const LatLng(-25.9650, 32.6000),
        const LatLng(-25.9550, 32.6150),
      ),
    ],
    'Alto Maé': [
      LatLngBounds(
        const LatLng(-25.9580, 32.5650),
        const LatLng(-25.9500, 32.5750),
      ),
    ],
  };

  static Future<Position> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Serviços de localização desativados');
        return _getDefaultPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Permissão de localização negada');
          return _getDefaultPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Permissão de localização negada permanentemente');
        return _getDefaultPosition();
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('❌ Erro ao obter localização: $e');
      return _getDefaultPosition();
    }
  }

  static Position _getDefaultPosition() {
    return Position(
      latitude: -25.9585, // Ajustado para Primeira Rotunda Intaka
      longitude: 32.5950,
      timestamp: DateTime.now(),
      accuracy: 100,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 100,
      headingAccuracy: 0,
    );
  }

  static Future<({LatLng position, String address})>
      getCurrentLocationWithAddress() async {
    final position = await getCurrentPosition();
    final latLng = LatLng(position.latitude, position.longitude);
    final address = await getAddressFromLatLng(latLng);
    return (position: latLng, address: address);
  }

  static Future<String> getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final street = place.street ?? '';
        final district = place.subLocality ?? '';
        final city = place.locality ?? '';

        if (street.isNotEmpty && district.isNotEmpty) {
          return '$street, $district';
        } else if (district.isNotEmpty) {
          return district;
        } else if (city.isNotEmpty) {
          return city;
        }
      }
      return 'Maputo, Moçambique';
    } catch (e) {
      debugPrint('❌ Erro geocoding: $e');
      return 'Maputo, Moçambique';
    }
  }

  static Future<String> getNeighborhood(LatLng latLng) async {
    // Primeiro tenta encontrar por bounds
    final neighborhoodByBounds = _findNeighborhoodByBounds(latLng);
    if (neighborhoodByBounds != null) {
      return neighborhoodByBounds;
    }

    // Se não encontrar, tenta via geocoding
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final neighborhood = place.subLocality ??
            place.subAdministrativeArea ??
            place.locality ??
            '';
        if (neighborhood.isNotEmpty && neighborhood != 'Maputo') {
          return neighborhood;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          return place.locality!;
        }
      }
      return _getNeighborhoodFallback(latLng.latitude, latLng.longitude);
    } catch (e) {
      debugPrint('❌ Erro ao obter bairro: $e');
      return _getNeighborhoodFallback(latLng.latitude, latLng.longitude);
    }
  }

  static String? _findNeighborhoodByBounds(LatLng point) {
    for (final entry in _neighborhoodBounds.entries) {
      for (final bounds in entry.value) {
        if (bounds.contains(point)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static String _getNeighborhoodFallback(double lat, double lng) {
    // Coordenadas específicas para Primeira Rotunda Intaka
    if (lat > -25.962 && lat < -25.952 && lng > 32.588 && lng < 32.600) {
      return 'Primeira Rotunda';
    }
    if (lat > -25.958 && lat < -25.950 && lng > 32.590 && lng < 32.602) {
      return 'Intaka';
    }
    if (lat > -25.960 && lat < -25.950 && lng > 32.578 && lng < 32.590) {
      return 'Sommerschield';
    }
    if (lat > -25.975 && lat < -25.960 && lng > 32.565 && lng < 32.580) {
      return 'Polana';
    }
    if (lat > -25.975 && lat < -25.965 && lng > 32.575 && lng < 32.588) {
      return 'Central';
    }
    if (lat > -25.955 && lat < -25.945 && lng > 32.555 && lng < 32.565) {
      return 'Coop';
    }
    if (lat > -25.970 && lat < -25.960 && lng > 32.555 && lng < 32.565) {
      return 'Malhangalene';
    }
    if (lat > -25.985 && lat < -25.975 && lng > 32.575 && lng < 32.588) {
      return 'Jardim';
    }
    if (lat > -25.955 && lat < -25.940 && lng > 32.600 && lng < 32.615) {
      return 'Mafalala';
    }
    if (lat > -25.970 && lat < -25.950 && lng > 32.620 && lng < 32.640) {
      return 'Costa do Sol';
    }
    if (lat > -25.965 && lat < -25.955 && lng > 32.600 && lng < 32.615) {
      return 'Maxaquene';
    }
    return 'Maputo';
  }

  static String getFullAddressFromPlacemark(Placemark place) {
    final parts = <String>[];
    if (place.street != null && place.street!.isNotEmpty)
      parts.add(place.street!);
    if (place.subLocality != null && place.subLocality!.isNotEmpty)
      parts.add(place.subLocality!);
    if (place.locality != null && place.locality!.isNotEmpty)
      parts.add(place.locality!);
    if (parts.isEmpty && place.name != null && place.name!.isNotEmpty)
      parts.add(place.name!);
    return parts.isNotEmpty ? parts.join(', ') : 'Maputo, Moçambique';
  }
}

// Classe auxiliar para bounds
class LatLngBounds {
  final LatLng southwest;
  final LatLng northeast;

  const LatLngBounds(this.southwest, this.northeast);

  bool contains(LatLng point) {
    return point.latitude >= southwest.latitude &&
        point.latitude <= northeast.latitude &&
        point.longitude >= southwest.longitude &&
        point.longitude <= northeast.longitude;
  }
}
