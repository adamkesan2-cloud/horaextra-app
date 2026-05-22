import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/domain/entities/user.dart';

class LoginUseCase {
  final ApiService _apiService;

  LoginUseCase(this._apiService);

  Future<User?> execute(String email, String password) async {
    try {
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      return User.fromJson(response['user']);
    } catch (e) {
      throw Exception('Erro ao fazer login: $e');
    }
  }
}
