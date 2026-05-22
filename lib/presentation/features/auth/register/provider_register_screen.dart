// lib/presentation/features/auth/register/provider_register_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/presentation/features/auth/login/view/login_screen.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({super.key});

  @override
  State<ProviderRegisterScreen> createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _specialtyController = TextEditingController();

  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;

  Map<String, dynamic>? _selectedLocation;
  String _address = '';

  List<String> _specialties = [];

  // ✅ Usa Uint8List (bytes) em vez de File — compatível com web e mobile
  Uint8List? _idDocumentBytes;
  String? _idDocumentFileName;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _descriptionController.dispose();
    _experienceYearsController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  // ── Localização ────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    if (_isLocationLoading) return;
    setState(() => _isLocationLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('GPS desativado. Ative o GPS e tente novamente.');
        return;
      }

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
            'Permissão bloqueada. Ative nas configurações do dispositivo.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      debugPrint('📍 Posição: ${position.latitude}, ${position.longitude}');

      // Fallback seguro: coordenadas brutas se geocoding falhar
      String address = 'Lat: ${position.latitude.toStringAsFixed(5)}, '
          'Lng: ${position.longitude.toStringAsFixed(5)}';

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 8));

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[
            if (place.street != null && place.street!.isNotEmpty) place.street!,
            if (place.subLocality != null && place.subLocality!.isNotEmpty)
              place.subLocality!,
            if (place.locality != null && place.locality!.isNotEmpty)
              place.locality!,
            if (place.administrativeArea != null &&
                place.administrativeArea!.isNotEmpty)
              place.administrativeArea!,
            if (place.country != null && place.country!.isNotEmpty)
              place.country!,
          ];
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } on TimeoutException {
        debugPrint('⚠️ Geocoding timeout, usando coordenadas');
      } catch (e) {
        // ✅ Captura "Unexpected null value" do geocoding no web
        debugPrint('⚠️ Geocoding indisponível, usando coordenadas: $e');
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
      debugPrint('❌ Erro de localização: $e');
      _showSnackBar('Não foi possível obter a localização.');
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  // ── Seleção do documento BI ────────────────────────────────────────────────

  Future<void> _pickIDDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData:
            true, // ✅ Carrega bytes diretamente — funciona na web e mobile
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes == null) {
          _showSnackBar('Não foi possível ler o arquivo. Tente novamente.');
          return;
        }

        setState(() {
          _idDocumentBytes = bytes;
          _idDocumentFileName = file.name;
        });

        _showSnackBar('Documento selecionado: ${file.name}', isError: false);
      }
    } catch (e) {
      debugPrint('❌ Erro ao selecionar documento: $e');
      _showSnackBar('Erro ao selecionar imagem. Tente novamente.');
    }
  }

  // ── Especialidades ─────────────────────────────────────────────────────────

  void _addSpecialty() {
    final specialty = _specialtyController.text.trim();
    if (specialty.isEmpty) return;
    if (_specialties.contains(specialty)) {
      _showSnackBar('Especialidade já adicionada.');
      return;
    }
    setState(() {
      _specialties.add(specialty);
      _specialtyController.clear();
    });
  }

  void _removeSpecialty(String specialty) {
    setState(() => _specialties.remove(specialty));
  }

  // ── Registro ───────────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      _showSnackBar('Aceite os termos de uso para continuar.');
      return;
    }
    if (_selectedLocation == null) {
      _showSnackBar('Selecione sua localização para continuar.');
      return;
    }
    if (_specialties.isEmpty) {
      _showSnackBar('Adicione pelo menos uma especialidade.');
      return;
    }
    if (_idDocumentBytes == null) {
      _showSnackBar('Envie uma foto do seu BI / Cartão de Cidadão.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.registerProvider({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
        'description': _descriptionController.text,
        'specialties': _specialties,
        'experience_years': _experienceYearsController.text,
        'location':
            _selectedLocation != null ? jsonEncode(_selectedLocation) : null,
        // ✅ Passa os bytes e o nome do ficheiro
        'id_document_bytes': _idDocumentBytes,
        'id_document_filename': _idDocumentFileName,
      });

      if (mounted) {
        if (success) {
          _showSnackBar(
            'Cadastro enviado! Aguarde aprovação do administrador.',
            isError: false,
          );
          await Future.delayed(const Duration(milliseconds: 1200));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        } else {
          _showSnackBar(
            authProvider.error ?? 'Erro ao enviar cadastro. Tente novamente.',
          );
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final hasDoc = _idDocumentBytes != null;

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
              width: isDesktop ? 700 : double.infinity,
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
                    // ── Cabeçalho ──────────────────────────────────────────
                    const Text(
                      'Cadastro de Prestador',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preencha seus dados para começar.\nSeu cadastro será analisado pela nossa equipe.',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.blueMedium),
                    ),
                    const SizedBox(height: 32),

                    // ── Dados pessoais ─────────────────────────────────────
                    _buildSectionTitle('Dados pessoais'),

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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Nome obrigatório';
                        if (v.trim().length < 3) return 'Nome muito curto';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'E-mail obrigatório';
                        if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$')
                            .hasMatch(v.trim())) {
                          return 'E-mail inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Telefone obrigatório';
                        if (v.trim().length < 9) return 'Telefone inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Localização ────────────────────────────────────────
                    _buildSectionTitle('Localização *'),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedLocation != null
                              ? AppColors.success
                              : AppColors.error,
                          width: _selectedLocation == null ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _selectedLocation != null
                            ? AppColors.success.withOpacity(0.04)
                            : AppColors.error.withOpacity(0.03),
                      ),
                      child: ListTile(
                        leading: Icon(
                          _selectedLocation != null
                              ? Icons.location_on
                              : Icons.location_on_outlined,
                          color: _selectedLocation != null
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        title: Text(
                          _address.isEmpty
                              ? 'Selecione sua localização *'
                              : _address,
                          style: TextStyle(
                            fontSize: 14,
                            color: _address.isEmpty
                                ? AppColors.error
                                : AppColors.primaryBlue,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _isLocationLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.my_location,
                                color: _selectedLocation != null
                                    ? AppColors.success
                                    : null,
                              ),
                        onTap: _isLocationLoading ? null : _getCurrentLocation,
                      ),
                    ),
                    if (_selectedLocation == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          'Obrigatório para prestadores',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.error),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ── Dados profissionais ────────────────────────────────
                    _buildSectionTitle('Dados profissionais'),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrição profissional',
                        hintText: 'Fale sobre sua experiência e serviços',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _experienceYearsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Anos de experiência',
                        prefixIcon: Icon(Icons.work_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Especialidades ─────────────────────────────────────
                    _buildSectionTitle('Especialidades'),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _specialtyController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Encanador, Eletricista...',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            onFieldSubmitted: (_) => _addSpecialty(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addSpecialty,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: AppColors.white,
                            minimumSize: const Size(48, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (_specialties.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _specialties.map((spec) {
                          return Chip(
                            label: Text(spec),
                            onDeleted: () => _removeSpecialty(spec),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor:
                                AppColors.primaryBlue.withOpacity(0.08),
                            labelStyle: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── Documento BI ───────────────────────────────────────
                    _buildSectionTitle('Documento de identificação *'),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: hasDoc ? AppColors.success : AppColors.border,
                          width: hasDoc ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color:
                            hasDoc ? AppColors.success.withOpacity(0.04) : null,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.badge_outlined,
                              color: hasDoc ? AppColors.success : null,
                            ),
                            title: Text(
                              hasDoc
                                  ? _idDocumentFileName!
                                  : 'Selecionar foto do BI / Cartão de Cidadão *',
                              style: TextStyle(
                                fontSize: 14,
                                color: hasDoc
                                    ? AppColors.success
                                    : AppColors.blueLight,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              hasDoc ? Icons.check_circle : Icons.upload_file,
                              color: hasDoc ? AppColors.success : null,
                            ),
                            onTap: _pickIDDocument,
                          ),
                          // ✅ Preview usando Image.memory (bytes) — funciona na web
                          if (_idDocumentBytes != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _idDocumentBytes!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Senha ──────────────────────────────────────────────
                    _buildSectionTitle('Senha'),

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
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Senha obrigatória';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Confirmação obrigatória';
                        if (v != _passwordController.text) {
                          return 'Senhas não conferem';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Termos ─────────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (v) =>
                              setState(() => _acceptedTerms = v ?? false),
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

                    // ── Botão enviar ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
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
                                'Enviar Cadastro',
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
