// lib/presentation/features/dashboard/client/client_dashboard.dart
//
// ALTERAÇÕES:
// - Removida a bottom navigation bar (Início / Pedidos / Perfil)
// - Perfil acessível via avatar no header da home screen
// - Pedidos acessíveis via Navigator.pushNamed a partir de qualquer tela
// - WillPopScope impede que o botão Voltar feche o dashboard

import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../profile/view/client_profile_screen.dart';
import 'client_home_screen.dart';
import 'client_requests_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      // forceRefresh omitido → usa o valor padrão false
      provider.ensureCategoriesLoaded(),
      provider.ensureServicesLoaded(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    if (_isLoading) return _buildLoadingScreen();

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(),
            const Expanded(child: ClientHomeScreen()),
          ],
        ),
      );
    }

    // ── Mobile: apenas a home screen, sem bottom nav ──────────────────────
    return WillPopScope(
      onWillPop: () async => false,
      child: const Scaffold(
        body: ClientHomeScreen(),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.access_time_filled,
                  color: AppColors.primaryBlue,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'HoraExtra',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Carregando...',
              style: TextStyle(
                color: AppColors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop sidebar ───────────────────────────────────────────────────────
  Widget _buildDesktopSidebar() {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width * 0.25,
      constraints: const BoxConstraints(maxWidth: 320, minWidth: 280),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.access_time_filled,
                        color: AppColors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'HoraExtra',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),

          // Menu desktop
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildDesktopNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Início',
                  onTap: () {},
                  isSelected: true,
                ),
                _buildDesktopNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Meus Pedidos',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClientRequestsScreen()),
                  ),
                  isSelected: false,
                ),
                _buildDesktopNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Perfil',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClientProfileScreen()),
                  ),
                  isSelected: false,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Logout
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Versão 1.0.0',
                    style: TextStyle(fontSize: 10, color: AppColors.grey500)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sair'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.creamMedium : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppColors.primaryBlue : AppColors.grey600,
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primaryBlue : AppColors.grey700,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.creamMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
