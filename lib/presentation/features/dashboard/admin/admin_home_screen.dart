import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/constants/app_text_styles.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/widgets/shared/custom_card.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/widgets/stat_card.dart';

class AdminHomeScreen extends StatelessWidget {
  final void Function(int index)? onNavigate;

  const AdminHomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final provider = Provider.of<AppProvider>(context);
    final stats = provider.getAdminStats();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20, isDesktop ? 30 : 20, isDesktop ? 40 : 20, 20),
            sliver: SliverToBoxAdapter(child: _buildHeader(context, isDesktop, provider)),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 20),
            sliver: SliverToBoxAdapter(child: _buildQuickStats(stats, isDesktop)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20, 32, isDesktop ? 40 : 20, 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? (MediaQuery.of(context).size.width > 1200 ? 4 : 2) : 2,
                crossAxisSpacing: isDesktop ? 20 : 12,
                mainAxisSpacing: isDesktop ? 20 : 12,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildListDelegate([
                StatCard(title: 'Total Usuários', value: stats['totalUsers']?.toString() ?? '0', icon: Icons.people_rounded, color: AppColors.info, isDesktop: isDesktop),
                StatCard(title: 'Prestadores', value: stats['totalProviders']?.toString() ?? '0', icon: Icons.handyman_rounded, color: AppColors.success, isDesktop: isDesktop),
                StatCard(title: 'Serviços', value: stats['totalServices']?.toString() ?? '0', icon: Icons.grid_view_rounded, color: const Color(0xFF8B5CF6), isDesktop: isDesktop),
                StatCard(title: 'Solicitações', value: stats['totalRequests']?.toString() ?? '0', icon: Icons.receipt_long_rounded, color: AppColors.warning, isDesktop: isDesktop),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20, 0, isDesktop ? 40 : 20, 32),
            sliver: SliverToBoxAdapter(child: _buildQuickActions(context, isDesktop)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20, 0, isDesktop ? 40 : 20, 40),
            sliver: SliverToBoxAdapter(child: _buildRecentActivity(context, isDesktop)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop, AppProvider provider) {
    final user = provider.currentUser;
    return CustomCard(
      backgroundColor: AppColors.primary,
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
      withShadow: true,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isDesktop ? 14 : 10),
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: isDesktop ? 34 : 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, ${user?.name.split(' ').first ?? 'Admin'} 👋',
                  style: TextStyle(fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text('Gerencie sua plataforma', style: TextStyle(fontSize: isDesktop ? 16 : 14, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> stats, bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            title: 'Novos Usuários',
            value: stats['newUsers']?.toString() ?? '+24',
            change: '+12%',
            icon: Icons.person_add_rounded,
            color: AppColors.success,
            isDesktop: isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 20 : 12),
        Expanded(
          child: _QuickStatCard(
            title: 'Pedidos Hoje',
            value: stats['todayRequests']?.toString() ?? '18',
            change: '+8%',
            icon: Icons.shopping_cart_rounded,
            color: AppColors.primary,
            isDesktop: isDesktop,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDesktop) {
    // Índices correspondem às telas no AdminDashboard:
    // 0=Home, 1=Categorias, 2=Serviços, 3=Prestadores, 4=Relatórios, 5=Configurações
    final quickActions = [
      {'title': 'Categorias', 'subtitle': 'Gerir categorias de serviços', 'icon': Icons.category_rounded, 'index': 1, 'color': AppColors.primary},
      {'title': 'Serviços', 'subtitle': 'Gerir serviços disponíveis', 'icon': Icons.home_repair_service_rounded, 'index': 2, 'color': AppColors.warning},
      {'title': 'Relatórios', 'subtitle': 'Visualizar relatórios', 'icon': Icons.analytics_rounded, 'index': 4, 'color': AppColors.success},
      {'title': 'Configurações', 'subtitle': 'Configurar a plataforma', 'icon': Icons.settings_rounded, 'index': 5, 'color': AppColors.info},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on_rounded, color: AppColors.warning, size: 28),
            const SizedBox(width: 12),
            Text('Ações Rápidas', style: AppTextStyles.sectionTitle(context)),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: isDesktop ? 20 : 12,
            mainAxisSpacing: isDesktop ? 20 : 12,
            childAspectRatio: isDesktop ? 1.2 : 1.1,
          ),
          itemCount: quickActions.length,
          itemBuilder: (context, i) {
            final action = quickActions[i];
            return _QuickActionCard(
              title: action['title']! as String,
              subtitle: action['subtitle']! as String,
              icon: action['icon']! as IconData,
              color: action['color']! as Color,
              onTap: () => onNavigate?.call(action['index']! as int),
              isDesktop: isDesktop,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDesktop) {
    final activities = [
      {'title': 'Novo prestador cadastrado', 'description': 'João Silva solicitou aprovação', 'time': 'há 5 minutos', 'icon': Icons.person_add_rounded, 'color': AppColors.success},
      {'title': 'Serviço concluído', 'description': 'Reparo elétrico finalizado', 'time': 'há 15 minutos', 'icon': Icons.check_circle_rounded, 'color': AppColors.info},
      {'title': 'Pagamento recebido', 'description': 'M-Pesa - MT 1,200', 'time': 'há 30 minutos', 'icon': Icons.attach_money_rounded, 'color': AppColors.warning},
      {'title': 'Avaliação recebida', 'description': '⭐ 5.0 - Ótimo serviço!', 'time': 'há 1 hora', 'icon': Icons.star_rounded, 'color': AppColors.primary},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.info, size: 28),
                const SizedBox(width: 12),
                Text('Atividade Recente', style: AppTextStyles.sectionTitle(context)),
              ],
            ),
            TextButton(
              onPressed: () => onNavigate?.call(4),
              child: Text('Ver Tudo', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _ActivityItem(
              title: activity['title']! as String,
              description: activity['description']! as String,
              time: activity['time']! as String,
              icon: activity['icon']! as IconData,
              color: activity['color']! as Color,
            );
          },
        ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title, value, change;
  final IconData icon;
  final Color color;
  final bool isDesktop;

  const _QuickStatCard({required this.title, required this.value, required this.change, required this.icon, required this.color, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomCard(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      withShadow: true,
      child: Row(
        children: [
          Container(
            width: isDesktop ? 48 : 40,
            height: isDesktop ? 48 : 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(isDesktop ? 12 : 10), border: Border.all(color: color.withOpacity(0.3))),
            child: Icon(icon, color: color, size: isDesktop ? 24 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: isDesktop ? 15 : 13, color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(value, style: TextStyle(fontSize: isDesktop ? 22 : 20, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, letterSpacing: -0.5)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(change, style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDesktop;

  const _QuickActionCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
      child: CustomCard(
        withShadow: true,
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isDesktop ? 48 : 44,
              height: isDesktop ? 48 : 44,
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(isDesktop ? 12 : 10)),
              child: Icon(icon, color: color, size: isDesktop ? 24 : 22),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: isDesktop ? 16 : 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: isDesktop ? 13 : 12, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title, description, time;
  final IconData icon;
  final Color color;

  const _ActivityItem({required this.title, required this.description, required this.time, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        withShadow: true,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            Text(time, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}