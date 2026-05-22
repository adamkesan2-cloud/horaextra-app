// lib/presentation/features/profile/view/edit_profile_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/data/models/user/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isLoading = false;
  bool _isUploading = false;
  String? _photoUrl;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
      _cityController.text = user.city ?? '';
      _photoUrl = user.photoUrl;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _selectedImageBytes = bytes);
        await _uploadImage(bytes);
      }
    } catch (e) {
      _showMessage('Erro ao selecionar imagem: $e', success: false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _selectedImageBytes = bytes);
        await _uploadImage(bytes);
      }
    } catch (e) {
      _showMessage('Erro ao tirar foto: $e', success: false);
    }
  }

  Future<void> _uploadImage(Uint8List bytes) async {
    setState(() => _isUploading = true);
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.uploadAvatarBytes(
        bytes,
        fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (result['success'] == true && mounted) {
        await _reloadUserData();
        setState(() {
          _photoUrl = result['photo_url'];
          _selectedImageBytes = null;
          _isUploading = false;
        });
        _showMessage('Foto atualizada com sucesso!', success: true);
      } else {
        setState(() => _isUploading = false);
        _showMessage('Erro: ${result['error'] ?? 'Falha no upload'}', success: false);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showMessage('Erro ao fazer upload: $e', success: false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.removeAvatar();
      
      await _reloadUserData();
      
      setState(() {
        _photoUrl = null;
        _selectedImageBytes = null;
        _isLoading = false;
      });
      
      _showMessage('Foto removida com sucesso!', success: true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Erro ao remover foto: $e', success: false);
    }
  }

  Future<void> _reloadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    try {
      final response = await apiService.getAuth('/users/me', forceRefresh: true);
      if (response['success'] == true) {
        final updatedUser = UserModel.fromJson(response['data'] ?? response['user']);
        authProvider.updateCurrentUser(updatedUser);
        
        if (mounted) {
          setState(() {
            _photoUrl = updatedUser.photoUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao recarregar usuário: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
      };
      
      final response = await apiService.updateProfile(data);
      
      if (response['success'] == true && mounted) {
        await _reloadUserData();
        _showMessage('Perfil atualizado com sucesso!', success: true);
        Navigator.pop(context);
      } else {
        _showMessage('Erro ao salvar: ${response['error']}', success: false);
      }
    } catch (e) {
      _showMessage('Erro ao salvar: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFullImageUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return '';
    if (photoUrl.startsWith('http')) return photoUrl;
    if (photoUrl.startsWith('data:')) return photoUrl;
    
    const baseUrl = 'https://horaextra-backend-production.up.railway.app';
    return photoUrl.startsWith('/') ? '$baseUrl$photoUrl' : '$baseUrl/$photoUrl';
  }

  void _showMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.creamDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryBlue),
              title: const Text('Tirar Foto',
                  style: TextStyle(color: AppColors.primaryBlue)),
              onTap: () { 
                Navigator.pop(context); 
                _takePhoto(); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primaryBlue),
              title: const Text('Escolher da Galeria',
                  style: TextStyle(color: AppColors.primaryBlue)),
              onTap: () { 
                Navigator.pop(context); 
                _pickImage(); 
              },
            ),
            if (_photoUrl != null || _selectedImageBytes != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Remover Foto',
                    style: TextStyle(color: AppColors.error)),
                onTap: () { 
                  Navigator.pop(context); 
                  _removePhoto(); 
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Editar Perfil',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.creamDark, height: 1)),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Salvar',
                style: TextStyle(
                    color: AppColors.primaryBlue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _isLoading || _isUploading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildAvatarSection(isMobile),
                    const SizedBox(height: 24),
                    _buildTextField(
                        controller: _nameController,
                        label: 'Nome Completo',
                        icon: Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField(
                        controller: _phoneController,
                        label: 'Telemóvel',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField(
                        controller: _addressController,
                        label: 'Endereço',
                        icon: Icons.location_on_outlined),
                    const SizedBox(height: 16),
                    _buildTextField(
                        controller: _cityController,
                        label: 'Cidade',
                        icon: Icons.location_city_outlined),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection(bool isMobile) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: isMobile ? 100 : 120,
            height: isMobile ? 100 : 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.clientGradient,
              border: Border.all(color: AppColors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
            ),
            child: ClipOval(
              child: _selectedImageBytes != null
                  ? Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.cover,
                      key: ValueKey('preview_${DateTime.now().millisecondsSinceEpoch}'),
                    )
                  : _photoUrl != null && _photoUrl!.isNotEmpty
                      ? Image.network(
                          _getFullImageUrl(_photoUrl),
                          fit: BoxFit.cover,
                          key: ValueKey(_photoUrl),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primaryBlue,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _avatarPlaceholder(isMobile),
                        )
                      : _avatarPlaceholder(isMobile),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _showImageOptions,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt,
                    color: AppColors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(bool isMobile) {
    return Center(
      child: Text(
        _nameController.text.isNotEmpty
            ? _nameController.text[0].toUpperCase()
            : 'U',
        style: TextStyle(
            fontSize: isMobile ? 40 : 48,
            fontWeight: FontWeight.w700,
            color: AppColors.white),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.primaryBlue),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo obrigatório';
        if (label == 'Telemóvel' && value.length < 9) {
          return 'Telemóvel inválido';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.blueLight),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.creamDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.creamDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: AppColors.creamLight,
      ),
    );
  }
}