// lib/core/services/api_service.dart (COMPLETO CORRIGIDO)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/cache_service.dart';

class ApiService {
  AuthProvider? _authProvider;
  final CacheService _cache = CacheService();
  final http.Client _client = http.Client();
  final Connectivity _connectivity = Connectivity();

  final Map<String, Future<dynamic>> _inFlight = {};

  ApiService([AuthProvider? authProvider]) {
    _authProvider = authProvider;
    _cache.init();
  }

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  AuthProvider? get authProvider => _authProvider;

  Future<bool> get _isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void invalidateCache(String path) {
    _cache.invalidate(path);
    _cache.invalidate('auth:$path');
    _inFlight.remove(path);
    _inFlight.remove('auth:$path');
    debugPrint('🗑️ Cache invalidado: $path');
  }

  void invalidatePattern(String pattern) {
    _cache.invalidatePattern(pattern);
    debugPrint('🗑️ Cache invalidado por padrão: $pattern');
  }

  void clearAllCache() {
    _cache.clear();
    _inFlight.clear();
    debugPrint('🗑️ Todos os caches limpos');
  }

  String _url(String path) => '${ApiConfig.baseUrl}$path';

  Map<String, String> _headers({String? token, String? etag}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (etag != null) 'If-None-Match': etag,
    };
  }

  dynamic _parse(http.Response response, String cacheKey) {
    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode == 304) {
      final cached = _cache.getCached(cacheKey);
      debugPrint('📦 304 Not Modified — usando cache: $cacheKey');
      return cached;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      final etag = response.headers['etag'];
      _cache.cacheData(cacheKey, decoded, etag: etag);
      return decoded;
    }

    final msg = _extractError(response);
    debugPrint('❌ Erro API: $msg');
    throw Exception(msg);
  }

  String _extractError(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      return body['message'] ?? body['error'] ?? 'Erro ${r.statusCode}';
    } catch (_) {
      return 'Erro ${r.statusCode}';
    }
  }

  // POST genérico (para login/register)
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    if (!await _isOnline) throw Exception('Sem conexão com a internet');

    debugPrint('📡 POST: $path');

    final response = await _client
        .post(Uri.parse(_url(path)),
            headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body.isEmpty ? '{}' : response.body);
    }
    throw Exception(_extractError(response));
  }

  // GET público
  Future<dynamic> get(String path, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.isFresh(path)) {
      debugPrint('⚡ Cache hit: $path');
      return _cache.getCached(path);
    }

    if (!await _isOnline) {
      final stale = _cache.getCached(path);
      if (stale != null) {
        debugPrint('📵 Offline — usando cache obsoleto: $path');
        return stale;
      }
      throw Exception('Sem conexão com a internet');
    }

    if (_inFlight.containsKey(path)) {
      debugPrint('🔄 Aguardando request em andamento: $path');
      return _inFlight[path];
    }

    final future = _doGet(path);
    _inFlight[path] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(path);
    }
  }

  Future<dynamic> _doGet(String path) async {
    final etag = _cache.getEtag(path);
    debugPrint('📡 GET: $path${etag != null ? " [ETag]" : ""}');

    try {
      final response = await _client
          .get(Uri.parse(_url(path)), headers: _headers(etag: etag))
          .timeout(const Duration(seconds: 15));

      return _parse(response, path);
    } on TimeoutException {
      final stale = _cache.getCached(path);
      if (stale != null) return stale;
      throw Exception('Timeout ao conectar');
    } catch (e) {
      final stale = _cache.getCached(path);
      if (stale != null) return stale;
      throw Exception('Erro de conexão: $e');
    }
  }

  // GET autenticado
  Future<dynamic> getAuth(String path, {bool forceRefresh = false}) async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');

    final cacheKey = 'auth:$path';

    // ✅ Se forceRefresh=true, ignorar cache completamente
    if (!forceRefresh && _cache.isFresh(cacheKey)) {
      debugPrint('⚡ Cache hit (auth): $path');
      return _cache.getCached(cacheKey);
    } else if (forceRefresh) {
      debugPrint('🔄 Force refresh: ignorando cache para $path');
    }

    if (!await _isOnline) {
      final stale = _cache.getCached(cacheKey);
      if (stale != null) return stale;
      throw Exception('Sem conexão com a internet');
    }

    if (_inFlight.containsKey(cacheKey)) {
      debugPrint('🔄 Aguardando request em andamento: $path');
      return _inFlight[cacheKey];
    }

    final future = _doGetAuth(path, token);
    _inFlight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<dynamic> _doGetAuth(String path, String token) async {
    final cacheKey = 'auth:$path';
    final etag = _cache.getEtag(cacheKey);
    debugPrint('📡 GET Auth: $path${etag != null ? " [ETag]" : ""}');

    try {
      final response = await _client
          .get(Uri.parse(_url(path)),
              headers: _headers(token: token, etag: etag))
          .timeout(const Duration(seconds: 15));

      return _parse(response, cacheKey);
    } on TimeoutException {
      final stale = _cache.getCached(cacheKey);
      if (stale != null) return stale;
      throw Exception('Timeout ao conectar');
    } catch (e) {
      final stale = _cache.getCached(cacheKey);
      if (stale != null) return stale;
      throw Exception('Erro de conexão: $e');
    }
  }

  // POST público
  Future<dynamic> postPublic(String path, Map<String, dynamic> body) async {
    if (!await _isOnline) throw Exception('Sem conexão com a internet');

    debugPrint('📡 POST Public: $path');

    final response = await _client
        .post(Uri.parse(_url(path)),
            headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body.isEmpty ? '{}' : response.body);
    }
    throw Exception(_extractError(response));
  }

  // POST autenticado
  Future<dynamic> postAuth(String path, Map<String, dynamic> body) async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');
    if (!await _isOnline) throw Exception('Sem conexão com a internet');

    debugPrint('📡 POST Auth: $path');

    final response = await _client
        .post(Uri.parse(_url(path)),
            headers: _headers(token: token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _invalidateRelated(path);
      return jsonDecode(response.body.isEmpty ? '{}' : response.body);
    }

    if (response.statusCode == 401) {
      await _authProvider?.refreshToken();
      final newToken = await _authProvider!.getToken();
      if (newToken != null) {
        final retryResponse = await _client
            .post(Uri.parse(_url(path)),
                headers: _headers(token: newToken), body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));

        if (retryResponse.statusCode >= 200 && retryResponse.statusCode < 300) {
          _invalidateRelated(path);
          return jsonDecode(retryResponse.body);
        }
      }
    }

    throw Exception(_extractError(response));
  }

  // PUT autenticado
  Future<dynamic> putAuth(String path, Map<String, dynamic> body) async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');
    if (!await _isOnline) throw Exception('Sem conexão com a internet');

    debugPrint('📡 PUT Auth: $path');

    final response = await _client
        .put(Uri.parse(_url(path)),
            headers: _headers(token: token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _invalidateRelated(path);
      return jsonDecode(response.body);
    }
    throw Exception(_extractError(response));
  }

  // PATCH autenticado
  Future<dynamic> patchAuth(String path, Map<String, dynamic> body) async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');
    if (!await _isOnline) throw Exception('Sem conexão com a internet');

    debugPrint('📡 PATCH Auth: $path');

    final response = await _client
        .patch(Uri.parse(_url(path)),
            headers: _headers(token: token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _invalidateRelated(path);
      return jsonDecode(response.body);
    }
    throw Exception(_extractError(response));
  }

  // DELETE autenticado
  Future<void> deleteAuth(String path) async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');
    if (!await _isOnline) throw Exception('Sem conexão com a internet');

    debugPrint('📡 DELETE Auth: $path');

    final response = await _client
        .delete(Uri.parse(_url(path)), headers: _headers(token: token))
        .timeout(const Duration(seconds: 15));

    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _invalidateRelated(path);
      return;
    }
    throw Exception(_extractError(response));
  }

  Future<Map<String, dynamic>> uploadAvatarBytes(
    Uint8List bytes, {
    String fileName = 'avatar.jpg',
  }) async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');

    // ✅ URL correta usando _url() que já adiciona /api
    final uri = Uri.parse(_url('/profile/avatar'));
    debugPrint('📡 Upload avatar para: $uri');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'avatar',
      bytes,
      filename: fileName,
      contentType: MediaType.parse('image/jpeg'),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    debugPrint('📥 Upload status: ${response.statusCode}');
    debugPrint('📥 Upload body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final result = jsonDecode(response.body);
      invalidateCache('/profile/client');
      invalidateCache('/profile/provider/own');
      invalidateCache('/users/me');
      return result;
    }

    throw Exception(
        'Erro ao fazer upload: ${response.statusCode} — ${response.body}');
  }

// Manter o antigo por compatibilidade mas redirecionar para o novo
  Future<Map<String, dynamic>> uploadAvatar(dynamic imageFile) async {
    Uint8List bytes;
    if (imageFile is Uint8List) {
      bytes = imageFile;
    } else if (imageFile is File) {
      bytes = await imageFile.readAsBytes();
    } else {
      throw Exception('Tipo de imagem não suportado');
    }
    return uploadAvatarBytes(bytes);
  }

  Future<Map<String, dynamic>> removeAvatar() async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');

    final response = await _client.delete(
      Uri.parse(_url('/profile/avatar')),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      invalidateCache('/profile/client');
      invalidateCache('/profile/provider/own');
      invalidateCache('/users/me');
      return jsonDecode(response.body);
    }
    throw Exception('Erro ao remover foto: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');

    final role = await _getUserRole();
    final endpoint =
        role == 'provider' ? '/profile/provider' : '/profile/client';

    final response = await _client.put(
      Uri.parse(_url(endpoint)),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      invalidateCache('/profile/client');
      invalidateCache('/profile/provider/own');
      invalidateCache('/users/me');
      return jsonDecode(response.body);
    }
    throw Exception('Erro ao atualizar perfil: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getPublicProviderProfile(
      String providerId) async {
    final token = await _authProvider?.getToken();
    final response = await _client.get(
      Uri.parse(_url('/profile/provider/public/$providerId')),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('Erro ao buscar perfil: ${response.statusCode}');
  }

  Future<String> _getUserRole() async {
    final token = await _authProvider?.getToken();
    if (token == null) return 'client';

    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        return payload['role'] ?? 'client';
      }
    } catch (e) {
      debugPrint('Erro ao decodificar token: $e');
    }
    return 'client';
  }

  Future<Map<String, dynamic>> getProviderStats() async {
    if (_authProvider == null) {
      throw Exception('ApiService não configurado com AuthProvider');
    }

    final token = await _authProvider!.getToken();
    if (token == null) throw Exception('Não autenticado');

    final response = await _client.get(
      Uri.parse(_url('/profile/provider/stats')),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return data['data'] ?? {};
    }
    return {};
  }

  void _invalidateRelated(String path) {
    if (path.contains('/categories')) invalidateCache('/categories');
    if (path.contains('/services')) invalidateCache('/services');
    if (path.contains('/requests')) {
      invalidatePattern('/requests');
      invalidatePattern('/stats');
    }
    if (path.contains('/providers')) {
      invalidatePattern('/providers');
      invalidatePattern('/nearby');
    }
    if (path.contains('/profile')) {
      invalidateCache('/profile/client');
      invalidateCache('/profile/provider/own');
      invalidateCache('/users/me');
    }
  }

  Future<dynamic> postMultipart(
    String path,
    Map<String, String> fields,
    Map<String, Uint8List> files,
    Map<String, String> fileNames,
  ) async {
    if (!await _isOnline) throw Exception('Sem conexão com a internet');

    debugPrint('📡 POST Multipart: $path');

    final uri = Uri.parse(_url(path));
    final request = http.MultipartRequest('POST', uri);

    fields.forEach((key, value) => request.fields[key] = value);

    for (final entry in files.entries) {
      final fileName = fileNames[entry.key] ?? entry.key;
      final ext = fileName.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      request.files.add(http.MultipartFile.fromBytes(
        entry.key,
        entry.value,
        filename: fileName,
        contentType: MediaType.parse(mime),
      ));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    debugPrint('📥 Status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body.isEmpty ? '{}' : response.body);
    }
    throw Exception(_extractError(response));
  }

  void dispose() => _client.close();
}
