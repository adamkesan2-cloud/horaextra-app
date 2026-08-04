// lib/core/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/core/services/token_service.dart';
import 'package:horaextra_app/data/models/user/user_model.dart';
import 'dart:convert';
import 'dart:typed_data';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final TokenService _tokenService = TokenService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  int _avatarVersion = 0; // ✅ Para forçar rebuild do avatar

  AuthProvider([ApiService? apiService])
      : _apiService = apiService ?? ApiService() {
    _apiService.setAuthProvider(this);
    _restoreSession();
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  String get userRole => _currentUser?.role ?? 'client';
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isProvider => _currentUser?.role == 'provider';
  bool get isClient => _currentUser?.role == 'client';

  /// ✅ Versão do avatar - incrementa quando a foto é atualizada
  int get avatarVersion => _avatarVersion;

  /// ✅ Força atualização do avatar
  void refreshAvatar() {
    _avatarVersion++;
    notifyListeners();
    debugPrint('🔄 Avatar version: $_avatarVersion');
  }

  Future<void> _restoreSession() async {
    final token = await _tokenService.getToken();
    if (token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getAuth('/users/me');
      if (response['success'] == true) {
        _currentUser = UserModel.fromJson(response['data'] ?? response['user']);
        await _connectWebSocket();
        notifyListeners();
        debugPrint('📌 Sessão restaurada: ${_currentUser?.email}');
      } else {
        await _tokenService.clearToken();
      }
    } catch (e) {
      debugPrint('❌ Erro ao restaurar sessão: $e');
      await _tokenService.clearToken();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getToken() async {
    return await _tokenService.getToken();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.postPublic('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response is Map && response['success'] == true) {
        final user =
            UserModel.fromJson(response['user'] as Map<String, dynamic>);
        final token = response['token'] as String;

        await _tokenService.saveToken(token);
        _currentUser = user;
        await _connectWebSocket();

        notifyListeners();
        debugPrint('✅ Login bem-sucedido: ${user.email}');
        debugPrint('✅ Role: ${user.role}');
        return true;
      } else {
        _error = response['message'] ?? 'Erro ao fazer login';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erro no login: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _connectWebSocket() async {
    if (_currentUser == null) return;
    final token = await _tokenService.getToken();
    if (token == null) return;
    final role = _currentUser!.role == 'provider' ? 'provider' : 'client';
    debugPrint('🔌 Conectando WebSocket para ${_currentUser!.name} como $role');
    await RealtimeWsService().connect(
      userId: _currentUser!.id,
      name: _currentUser!.name,
      role: role,
      token: token,
      lat: -25.9692,
      lng: 32.5732,
      isOnline: true,
    );
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.postPublic('/auth/register', userData);

      if (response is Map && response['success'] == true) {
        final user =
            UserModel.fromJson(response['user'] as Map<String, dynamic>);
        final token = response['token'] as String;

        await _tokenService.saveToken(token);
        _currentUser = user;
        await _connectWebSocket();

        notifyListeners();
        debugPrint('✅ Registro bem-sucedido: ${user.email}');
        return true;
      } else {
        _error = response['message'] ?? 'Erro ao registrar';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerProvider(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Extrair bytes e filename do mapa
      final idDocumentBytes =
          userData.remove('id_document_bytes') as Uint8List?;
      final idDocumentFileName =
          userData.remove('id_document_filename') as String? ?? 'document.jpg';

      // Converter todos os campos para String
      final fields = <String, String>{};
      userData.forEach((key, value) {
        if (value is List) {
          fields[key] = jsonEncode(value);
        } else if (value != null) {
          fields[key] = value.toString();
        }
      });

      final files = <String, Uint8List>{};
      final fileNames = <String, String>{};
      if (idDocumentBytes != null) {
        files['id_document'] = idDocumentBytes;
        fileNames['id_document'] = idDocumentFileName;
      }

      final response = await _apiService.postMultipart(
        '/auth/register-provider',
        fields,
        files,
        fileNames,
      );

      if (response is Map && response['success'] == true) {
        notifyListeners();
        debugPrint('✅ Prestador cadastrado, aguardando aprovação');
        return true;
      } else {
        _error = response['error'] ??
            response['message'] ??
            'Erro ao registrar prestador';
        return false;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      debugPrint('❌ Erro no registro de prestador: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.postAuth('/auth/logout', {});
    } catch (e) {
      debugPrint('Erro ao fazer logout: $e');
    }

    await _tokenService.clearToken();
    await RealtimeWsService().disconnect();
    _currentUser = null;
    notifyListeners();
    debugPrint('🔓 Logout realizado');
  }

  Future<bool> refreshToken() async {
    try {
      final response = await _apiService.postPublic('/auth/refresh-token', {});
      if (response is Map &&
          response['success'] == true &&
          response['token'] != null) {
        await _tokenService.saveToken(response['token'] as String);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erro ao renovar token: $e');
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// ✅ Método para atualizar o usuário localmente e forçar refresh do avatar
  void updateCurrentUser(UserModel updatedUser) {
    final photoChanged = _currentUser?.photoUrl != updatedUser.photoUrl;
    _currentUser = updatedUser;

    if (photoChanged) {
      _avatarVersion++; // ✅ Incrementa versão do avatar
      debugPrint('📸 Foto atualizada, avatar version: $_avatarVersion');
    }

    notifyListeners();
  }

  /// ✅ Método para recarregar os dados do usuário do backend
  Future<void> reloadUser() async {
    try {
      final response =
          await _apiService.getAuth('/users/me', forceRefresh: true);
      if (response['success'] == true) {
        final updatedUser =
            UserModel.fromJson(response['data'] ?? response['user']);
        updateCurrentUser(updatedUser);
        debugPrint('✅ Usuário recarregado: ${updatedUser.name}');
      }
    } catch (e) {
      debugPrint('❌ Erro ao recarregar usuário: $e');
    }
  }
}
