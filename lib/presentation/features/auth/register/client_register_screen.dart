// lib/presentation/features/auth/register/client_register_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/presentation/features/auth/login/view/login_screen.dart';
import 'package:provider/provider.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;

  Map<String, dynamic>? _selectedLocation;
  String _address = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Localização ────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    if (_isLocationLoading) return;

    setState(() => _isLocationLoading = true);

    try {
      // 1. Verificar se o serviço de GPS está ativo
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('GPS desativado. Ative o GPS e tente novamente.');
        return;
      }

      // 2. Verificar e solicitar permissão
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showSnackBar('Permissão de localização negada.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          'Permissão bloqueada. Ative nas configurações do dispositivo.',
        );
        return;
      }

      // 3. Obter posição com timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      debugPrint(
        '📍 Posição obtida: ${position.latitude}, ${position.longitude}',
      );

      // 4. Geocoding reverso com timeout e fallback
      String address = 'Lat: ${position.latitude.toStringAsFixed(5)}, '
          'Lng: ${position.longitude.toStringAsFixed(5)}';

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 8));

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((e) => e != null && e!.isNotEmpty).toList();

          if (parts.isNotEmpty) {
            address = parts.join(', ');
          }
        }
      } on TimeoutException {
        debugPrint('⚠️ Geocoding timeout, usando coordenadas como fallback');
      } catch (e) {
        debugPrint('⚠️ Erro no geocoding, usando coordenadas: $e');
      }

      if (mounted) {
        setState(() {
          _selectedLocation = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'address': address,
          };
          _address = address;
        });

        _showSnackBar('Localização obtida com sucesso!', isError: false);
      }
    } on TimeoutException {
      _showSnackBar('Tempo esgotado ao obter localização. Tente novamente.');
    } catch (e) {
      debugPrint('❌ Erro ao obter localização: $e');
      _showSnackBar('Não foi possível obter a localização.');
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  // ── Registro ───────────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      _showSnackBar('Aceite os termos de uso para continuar.');
      return;
    }

    // ✅ Localização é OPCIONAL — não bloqueia o cadastro
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.register({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
      });

      if (mounted) {
        if (success) {
          _showSnackBar('Cadastro realizado com sucesso!', isError: false);

          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        } else {
          final errorMsg =
              authProvider.error ?? 'Erro ao cadastrar. Tente novamente.';
          _showSnackBar(errorMsg);
        }
      }
    } catch (e) {
      debugPrint('❌ Erro inesperado no cadastro: $e');
      if (mounted) _showSnackBar('Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 48 : 24),
            child: Container(
              width: isDesktop ? 600 : double.infinity,
              padding: EdgeInsets.all(isDesktop ? 32 : 24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    const Text(
                      'Cadastro de Cliente',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preencha seus dados para começar',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.blueMedium,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Nome completo
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nome obrigatório';
                        }
                        if (value.trim().length < 3) {
                          return 'Nome muito curto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'E-mail obrigatório';
                        }
                        if (!RegExp(
                          r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
                        ).hasMatch(value.trim())) {
                          return 'E-mail inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Telefone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone (ex: +258840000000)',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Telefone obrigatório';
                        }
                        if (value.trim().length < 9) {
                          return 'Telefone inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Localização (opcional)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedLocation != null
                                  ? AppColors.success
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              _selectedLocation != null
                                  ? Icons.location_on
                                  : Icons.location_on_outlined,
                              color: _selectedLocation != null
                                  ? AppColors.success
                                  : null,
                            ),
                            title: Text(
                              _address.isEmpty
                                  ? 'Adicionar localização (opcional)'
                                  : _address,
                              style: TextStyle(
                                fontSize: 14,
                                color: _address.isEmpty
                                    ? AppColors.blueLight
                                    : AppColors.primaryBlue,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _isLocationLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            onTap:
                                _isLocationLoading ? null : _getCurrentLocation,
                          ),
                        ),
                        if (_selectedLocation == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 12),
                            child: Text(
                              'A localização é opcional mas ajuda a encontrar prestadores próximos',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.blueMedium,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Senha
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Senha obrigatória';
                        }
                        if (value.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirmar senha
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible,
                          ),
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirmação de senha obrigatória';
                        }
                        if (value != _passwordController.text) {
                          return 'Senhas não conferem';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Termos de uso
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (value) =>
                              setState(() => _acceptedTerms = value ?? false),
                          activeColor: AppColors.primaryBlue,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _acceptedTerms = !_acceptedTerms),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Li e aceito os Termos de Uso e Política de Privacidade',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botão cadastrar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isLocationLoading)
                            ? null
                            : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Cadastrar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
