// lib/presentation/features/auth/role_selection/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/presentation/features/auth/register/client_register_screen.dart';
import 'package:horaextra_app/presentation/features/auth/register/provider_register_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 48 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: isDesktop ? 120 : 80,
                  height: isDesktop ? 120 : 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryCream,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: AppColors.primaryBlue,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Criar Conta',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryCream,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Escolha como deseja usar o HoraExtra',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryCream.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 48),
                // Cards de opções
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 100 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _buildRoleCard(
                          context,
                          title: 'Cliente',
                          description:
                              'Contrate serviços profissionais\nde forma rápida e segura',
                          icon: Icons.person_outline_rounded,
                          color: AppColors.success,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClientRegisterScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildRoleCard(
                          context,
                          title: 'Prestador',
                          description:
                              'Ofereça seus serviços\ne ganhe dinheiro',
                          icon: Icons.build_rounded,
                          color: AppColors.warning,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProviderRegisterScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Já tem conta? ',
                      style: TextStyle(
                        color: AppColors.primaryCream.withOpacity(0.8),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Fazer login',
                        style: TextStyle(
                          color: AppColors.primaryCream,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.blueMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Cadastrar como $title'),
            ),
          ],
        ),
      ),
    );
  }
}
