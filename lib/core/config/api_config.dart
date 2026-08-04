// lib/core/config/api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _railwayHost =
      'horaextra-backend-production.up.railway.app';
  static const String _railwayBase = 'https://$_railwayHost';
  static const String prodBase = '$_railwayBase/api';

  static const String _localHostWeb = 'localhost';
  static const String _localHostMobile = '10.0.2.2';
  static const int _localPort = 4000;

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

  static String get wsUrl {
    if (isProduction) return 'wss://$_railwayHost/ws';
    if (kIsWeb) return 'ws://$_localHostWeb:$_localPort/ws';
    return 'ws://$_localHostMobile:$_localPort/ws';
  }

  static String wsUrlWithToken(String token) {
    if (token.isEmpty) return wsUrl;
    final t = token.trim();
    if (isProduction) return 'wss://$_railwayHost/ws?token=$t';
    if (kIsWeb) return 'ws://$_localHostWeb:$_localPort/ws?token=$t';
    return 'ws://$_localHostMobile:$_localPort/ws?token=$t';
  }

  // Auth
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get registerProvider => '$baseUrl/auth/register-provider';
  static String get logout => '$baseUrl/auth/logout';
  static String get refreshToken => '$baseUrl/auth/refresh-token';
  static String get changePassword => '$baseUrl/auth/change-password';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get resetPassword => '$baseUrl/auth/reset-password';

  // Users
  static String get users => '$baseUrl/users';
  static String get myProfile => '$baseUrl/users/me';
  static String userById(String id) => '$baseUrl/users/$id';
  static String updateProfile(String id) => '$baseUrl/users/$id';
  static String updateUserStatus(String id) => '$baseUrl/users/$id/status';

  // Services
  static String get categories => '$baseUrl/categories';
  static String get services => '$baseUrl/services';
  static String get popularServices => '$baseUrl/services/popular';
  static String serviceById(String id) => '$baseUrl/services/$id';
  static String get serviceSearch => '$baseUrl/services/search';

  // Providers
  static String get nearbyProviders => '$baseUrl/providers/nearby';
  static String get providerStats => '$baseUrl/providers/me/stats';
  static String get providerProfile => '$baseUrl/providers/me';
  static String get updateProviderProfile => '$baseUrl/providers/me';
  static String get updateProviderAvailability =>
      '$baseUrl/providers/me/availability';
  static String get myProviderReviews => '$baseUrl/providers/me/reviews';

  // Requests
  static String get requests => '$baseUrl/requests';
  static String get clientRequests => '$baseUrl/requests/client';
  static String get providerPendingRequests =>
      '$baseUrl/requests/provider/pending';
  static String get providerActiveServices =>
      '$baseUrl/requests/provider/active';
  static String requestById(String id) => '$baseUrl/requests/$id';
  static String acceptRequest(String id) => '$baseUrl/requests/$id/accept';
  static String rejectRequest(String id) => '$baseUrl/requests/$id/reject';
  static String completeRequest(String id) => '$baseUrl/requests/$id/complete';
  static String cancelRequest(String id) => '$baseUrl/requests/$id/cancel';

  // Payments
  static String get payments => '$baseUrl/payments';
  static String get paymentMethods => '$baseUrl/payments/methods';
  static String processPayment(String id) => '$baseUrl/payments/$id/process';

  // Reviews
  static String get reviews => '$baseUrl/reviews';
  static String providerReviews(String providerId) =>
      '$baseUrl/reviews/provider/$providerId';
  static String userReviews(String userId) => '$baseUrl/reviews/user/$userId';

  // Utils
  static String get healthCheck => '$baseUrl/health';
  static String get routeUrl => '$baseUrl/route';
  static String get uploadImage => '$baseUrl/upload';
  static String get sendNotification => '$baseUrl/notifications/send';

  // Headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Map<String, String> multipartHeaders(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static String getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://') ||
        imagePath.startsWith('data:')) return imagePath;
    String clean = imagePath;
    if (clean.startsWith('/api/../'))
      clean = clean.replaceFirst('/api/../', '/');
    if (clean.startsWith('api/../')) clean = clean.replaceFirst('api/../', '/');
    final finalPath = clean.startsWith('/') ? clean : '/$clean';
    return '$baseUrlImage$finalPath';
  }

  static String getAvatarUrl(String? photoUrl, {int? timestamp}) {
    final base = getFullImageUrl(photoUrl);
    if (base.isEmpty) return '';
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    return '$base?t=$ts';
  }

  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static void printConfig() {
    debugPrint('🔧 ApiConfig:');
    debugPrint(
        '   environment: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    debugPrint('   baseUrl: $baseUrl');
    debugPrint('   wsUrl: $wsUrl');
    debugPrint('   isProduction: $isProduction');
  }
}
