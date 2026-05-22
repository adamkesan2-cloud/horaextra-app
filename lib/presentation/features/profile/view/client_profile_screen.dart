// lib/presentation/features/profile/view/client_profile_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/data/models/user/user_model.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import 'package:http/http.dart' as http;

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
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
        setState(() {
          _selectedImageBytes = bytes;
        });
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
        setState(() {
          _selectedImageBytes = bytes;
        });
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
      
      // ✅ Upload usando o método corrigido
      final result = await apiService.uploadAvatarBytes(
        bytes,
        fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (result['success'] == true && mounted) {
        // ✅ Recarregar dados do usuário
        await _reloadUserData();
        
        // ✅ Atualizar estado local
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

      // ✅ Recarregar dados do usuário
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
      // ✅ Forçar refresh para ignorar cache
      final response = await apiService.getAuth('/users/me', forceRefresh: true);
      
      if (response['success'] == true) {
        final updatedUser = UserModel.fromJson(response['data'] ?? response['user']);
        authProvider.updateCurrentUser(updatedUser);
        
        // ✅ Atualizar URL da foto
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

  String _getFullImageUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return '';
    if (photoUrl.startsWith('http')) return photoUrl;
    if (photoUrl.startsWith('data:')) return photoUrl;
    
    // ✅ URL base correta
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

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da Conta',
            style: TextStyle(color: AppColors.primaryBlue)),
        content: const Text('Tem certeza que deseja sair?',
            style: TextStyle(color: AppColors.blueMedium)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.blueMedium)),
          ),
          ElevatedButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final isTablet = size.width >= 768 && size.width < 1200;
    
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Meu Perfil',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppColors.creamDark, height: 1)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.editProfile),
          ),
        ],
      ),
      body: _isLoading || _isUploading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(user, isMobile, isTablet),
                  const SizedBox(height: 16),
                  _buildInfoCard(user, isMobile, isTablet),
                  const SizedBox(height: 16),
                  _buildAccountSettings(context, authProvider, isMobile, isTablet),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(UserModel? user, bool isMobile, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isMobile ? 20 : 24),
          bottomRight: Radius.circular(isMobile ? 20 : 24),
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Stack(
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
                              errorBuilder: (_, __, ___) => _avatarPlaceholder(user, isMobile),
                            )
                          : _avatarPlaceholder(user, isMobile),
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
          SizedBox(height: isMobile ? 12 : 16),
          Text(user?.name ?? 'Cliente',
              style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue)),
          const SizedBox(height: 8),
          Text(user?.email ?? 'email@exemplo.com',
              style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: AppColors.blueMedium)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.creamMedium,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.creamDark)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today,
                    color: AppColors.primaryBlue, size: 14),
                const SizedBox(width: 6),
                Text('Membro desde ${_formatDate(user?.createdAt)}',
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 11 : 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(UserModel? user, bool isMobile) {
    return Center(
      child: Text(
        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'C',
        style: TextStyle(
            fontSize: isMobile ? 40 : 48,
            fontWeight: FontWeight.w700,
            color: AppColors.white),
      ),
    );
  }

  Widget _buildInfoCard(UserModel? user, bool isMobile, bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informações Pessoais',
              style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone_outlined, 'Telemóvel',
              user?.phone ?? 'Não informado', isMobile),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_outlined, 'Endereço',
              user?.address ?? 'Não informado', isMobile),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_city_outlined, 'Cidade',
              user?.city ?? 'Não informado', isMobile),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, bool isMobile) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          decoration: BoxDecoration(
              color: AppColors.creamMedium,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon,
              size: isMobile ? 14 : 16, color: AppColors.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: AppColors.blueLight)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSettings(BuildContext context, AuthProvider authProvider,
      bool isMobile, bool isTablet) {
    final settings = [
      {
        'icon': Icons.person_outline,
        'label': 'Editar Perfil',
        'route': AppRoutes.editProfile
      },
      {
        'icon': Icons.payment_outlined,
        'label': 'Métodos de Pagamento',
        'route': AppRoutes.clientPayments
      },
      {
        'icon': Icons.notifications_outlined,
        'label': 'Notificações',
        'route': AppRoutes.clientNotifications
      },
      {
        'icon': Icons.lock_outline,
        'label': 'Privacidade e Segurança',
        'route': AppRoutes.privacy
      },
      {
        'icon': Icons.help_outline,
        'label': 'Ajuda e Suporte',
        'route': AppRoutes.help
      },
      {
        'icon': Icons.description_outlined,
        'label': 'Termos de Uso',
        'route': AppRoutes.terms
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configurações',
              style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue)),
          SizedBox(height: isMobile ? 12 : 16),
          ...settings
              .map((setting) => ListTile(
                    dense: isMobile,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: isMobile ? 4 : 8),
                    leading: Icon(setting['icon'] as IconData,
                        color: AppColors.primaryBlue, size: isMobile ? 20 : 22),
                    title: Text(setting['label'] as String,
                        style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            color: AppColors.primaryBlue)),
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.blueLight, size: isMobile ? 18 : 20),
                    onTap: () => Navigator.pushNamed(
                        context, setting['route'] as String),
                  ))
              .toList(),
          const Divider(height: 24, color: AppColors.creamDark),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, authProvider),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair da Conta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '2024';
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}