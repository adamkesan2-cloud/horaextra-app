// lib/core/config/api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  // ── URLs por ambiente ──────────────────────────────────────────────────────
  // ✅ URL do Railway (produção)
  static const String _railwayHost = 'horaextra-backend-production.up.railway.app';
  static const String _railwayBase = 'https://$_railwayHost';
  static const String prodBase = '$_railwayBase/api';
  
  // URLs de desenvolvimento
  static const String _localHostWeb = 'localhost';
  static const String _localHostMobile = '10.0.2.2';
  static const int _localPort = 4000;

  // Detectar ambiente
  static bool get isProduction {
    if (kIsWeb) {
      final host = Uri.base.host;
      return host.contains('vercel.app') || 
             host.contains('railway.app') ||
             host.contains('horaextra') ||
             host == _railwayHost;
    }
    return const bool.fromEnvironment('dart.vm.product') || kReleaseMode;
  }

  static bool get isDevelopment => !isProduction;

  static String get baseUrl {
    if (isProduction) return prodBase;
    if (kIsWeb) return 'http://$_localHostWeb:$_localPort/api';
    return 'http://$_localHostMobile:$_localPort/api';
  }

  static String get baseUrlImage {
    if (isProduction) return _railwayBase;
    if (kIsWeb) return 'http://$_localHostWeb:$_localPort';
    return 'http://$_localHostMobile:$_localPort';
  }

  // ✅ WebSocket URL
  static String get wsUrl {
    if (isProduction) return 'wss://$_railwayHost/ws';
    if (kIsWeb) return 'ws://$_localHostWeb:$_localPort/ws';
    return 'ws://$_localHostMobile:$_localPort/ws';
  }

  // ── Rotas de API ──────────────────────────────────────────────────────────
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get registerProvider => '$baseUrl/auth/register-provider';
  static String get logout => '$baseUrl/auth/logout';
  static String get refreshToken => '$baseUrl/auth/refresh-token';

  static String get users => '$baseUrl/users';
  static String get myProfile => '$baseUrl/users/me';
  static String userById(String id) => '$baseUrl/users/$id';

  static String get categories => '$baseUrl/categories';
  static String get services => '$baseUrl/services';
  static String get nearbyProviders => '$baseUrl/providers/nearby';

  static String get requests => '$baseUrl/requests';
  static String get clientRequests => '$baseUrl/requests/client';
  static String get providerPendingRequests => '$baseUrl/requests/provider/pending';
  static String get providerActiveServices => '$baseUrl/requests/provider/active';

  static String get providerStats => '$baseUrl/providers/me/stats';

  static String get healthCheck => '$baseUrl/health';
  static String get routeUrl => '$baseUrl/route';

  static String get uploadImage => '$baseUrl/upload';

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// ✅ Converte path relativo em URL completa para imagens
  static String getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    
    // ✅ Se já é URL completa ou data URL, retorna como está
    if (imagePath.startsWith('http://') || 
        imagePath.startsWith('https://') || 
        imagePath.startsWith('data:')) {
      return imagePath;
    }
    
    // ✅ Remove prefixos problemáticos
    String clean = imagePath;
    if (clean.startsWith('/api/../')) {
      clean = clean.replaceFirst('/api/../', '/');
    }
    if (clean.startsWith('api/../')) {
      clean = clean.replaceFirst('api/../', '/');
    }
    
    // ✅ Garante que começa com /
    final finalPath = clean.startsWith('/') ? clean : '/$clean';
    
    return '$baseUrlImage$finalPath';
  }

  /// ✅ Gera URL para avatar com timestamp (força recarregamento)
  static String getAvatarUrl(String? photoUrl, {int? timestamp}) {
    final baseUrl = getFullImageUrl(photoUrl);
    if (baseUrl.isEmpty) return '';
    
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl?t=$ts';
  }

  static void printConfig() {
    debugPrint('🔧 ApiConfig:');
    debugPrint('   baseUrl: $baseUrl');
    debugPrint('   baseUrlImage: $baseUrlImage');
    debugPrint('   wsUrl: $wsUrl');
    debugPrint('   isProduction: $isProduction');
    debugPrint('   isWeb: $kIsWeb');
  }
}