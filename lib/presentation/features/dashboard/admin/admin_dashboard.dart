import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_home_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_categories_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_services_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_providers_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_reports_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_settings_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminHomeScreen(),
    AdminCategoriesScreen(),
    AdminServicesScreen(),
    AdminProvidersScreen(),
    AdminReportsScreen(),
    AdminSettingsScreen(),
  ];

  final List<String> _titles = [
    'Início',
    'Categorias',
    'Serviços',
    'Prestadores',
    'Relatórios',
    'Configurações',
  ];

  final List<IconData> _icons = [
    Icons.home_rounded,
    Icons.category_rounded,
    Icons.home_repair_service_rounded,
    Icons.people_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().loadAdminStats();
    });
  }

  String _s(AppProvider p, String key) {
    final m = p.getAdminStats();
    final val = m[key];
    if (val == null) return '0';
    return val.toString();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair', style: TextStyle(color: AppColors.primaryBlue)),
        content: const Text('Tem certeza que deseja sair?', style: TextStyle(color: AppColors.blueMedium)),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.blueMedium),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _changePage(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final size = MediaQuery.of(context).size;

    if (size.width > 900) return _buildDesktopLayout(context);
    if (size.width > 600) return _buildTabletLayout(context);
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex], style: const TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _changePage,
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.creamMedium,
          destinations: List.generate(
            _icons.length,
            (i) => NavigationDestination(
              icon: Icon(_icons[i], color: _currentIndex == i ? AppColors.primaryBlue : AppColors.blueLight),
              label: _titles[i],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 100,
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(right: BorderSide(color: AppColors.creamDark.withOpacity(0.3))),
          ),
          child: NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _changePage,
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.white,
            indicatorColor: AppColors.creamMedium,
            selectedIconTheme: const IconThemeData(color: AppColors.primaryBlue),
            unselectedIconTheme: const IconThemeData(color: AppColors.blueLight),
            selectedLabelTextStyle: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
            unselectedLabelTextStyle: const TextStyle(color: AppColors.blueLight),
            destinations: List.generate(
              _icons.length,
              (i) => NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_titles[i])),
            ),
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: Scaffold(
            appBar: AppBar(
              title: Text(_titles[_currentIndex], style: const TextStyle(color: AppColors.white)),
              backgroundColor: AppColors.primaryBlue,
              elevation: 0,
              actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
            ),
            body: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(right: BorderSide(color: AppColors.creamDark.withOpacity(0.3))),
              boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(2, 0))],
            ),
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.creamDark.withOpacity(0.3))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: const Center(
                          child: Text('HE', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('HoraExtra', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                    ],
                  ),
                ),

                // Stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _StatCard(value: _s(provider, 'totalUsers'), label: 'Usuários')),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(value: _s(provider, 'totalProviders'), label: 'Prestadores')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _StatCard(value: _s(provider, 'totalServices'), label: 'Serviços')),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(value: _s(provider, 'totalRequests'), label: 'Pedidos')),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.creamDark),

                // Menu items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: List.generate(
                      _icons.length,
                      (i) => _NavItem(
                        index: i,
                        icon: _icons[i],
                        label: _titles[i],
                        isSelected: _currentIndex == i,
                        onTap: () => _changePage(i),
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1, color: AppColors.creamDark),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: AppColors.creamMedium, borderRadius: BorderRadius.circular(8)),
                          child: Icon(
                            provider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        title: Text(
                          provider.isDarkMode ? 'Modo Claro' : 'Modo Escuro',
                          style: const TextStyle(fontSize: 13, color: AppColors.primaryBlue),
                        ),
                        onTap: () => provider.toggleDarkMode(),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text('Sair'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Versão 1.0.0', style: TextStyle(fontSize: 10, color: AppColors.blueLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border(bottom: BorderSide(color: AppColors.creamDark.withOpacity(0.3))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titles[_currentIndex],
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.creamMedium, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.notifications_outlined, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _screens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.creamMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.blueMedium)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.index, required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
          child: Icon(icon, color: isSelected ? AppColors.primaryBlue : AppColors.blueLight, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primaryBlue : AppColors.blueMedium,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.creamMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }
}