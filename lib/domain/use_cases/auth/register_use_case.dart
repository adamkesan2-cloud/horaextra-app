import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/domain/entities/user.dart';

class RegisterUseCase {
  final ApiService _apiService;

  RegisterUseCase(this._apiService);

  Future<User?> execute({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _apiService.post('/auth/register', {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      });

      return User.fromJson(response['user']);
    } catch (e) {
      throw Exception('Erro ao registrar: $e');
    }
  }
}
