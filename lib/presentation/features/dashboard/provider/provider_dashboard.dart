// lib/presentation/features/dashboard/provider/provider_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_home.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_requests_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_history_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_services_screen.dart';
import 'package:horaextra_app/presentation/features/profile/view/provider_own_profile_screen.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  int _currentIndex = 0;
  bool _isLoading = true;
  int _pendingRequestsCount = 0;
  Timer? _pollTimer;

  final List<Widget> _screens = [
    const ProviderHome(),           // Mapa - SEM navegação inferior
    const ProviderServicesScreen(),
    const ProviderRequestsScreen(),
    const ProviderHistoryScreen(),
    const ProviderOwnProfileScreen(),
  ];

  final List<String> _titles = [
    'Mapa',
    'Serviços',
    'Pedidos',
    'Histórico',
    'Perfil',
  ];

  final List<IconData> _icons = [
    Icons.map_rounded,
    Icons.home_repair_service_rounded,
    Icons.notifications_active_rounded,
    Icons.history_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startPolling();
    _listenToWsPendingRequests();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchPendingCount();
    });
  }

  void _listenToWsPendingRequests() {
    RealtimeWsService().pendingRequests.listen((requests) {
      if (mounted) {
        final ap = Provider.of<AppProvider>(context, listen: false);
        ap.setPendingRequestsFromWs(requests);
        _updatePendingCount();
      }
    });
  }

  Future<void> _updatePendingCount() async {
    if (mounted) {
      final ap = Provider.of<AppProvider>(context, listen: false);
      setState(() {
        _pendingRequestsCount = ap.pendingRequests.length;
      });
    }
  }

  Future<void> _fetchPendingCount() async {
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.getProviderPendingRequests(forceRefresh: true);
      if (mounted) {
        setState(() {
          _pendingRequestsCount = ap.pendingRequests.length;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar contador: $e');
    }
  }

  Future<void> _initializeData() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      provider.loadCategories(),
      provider.loadServices(),
      provider.loadProviderStats(),
      provider.getProviderPendingRequests(),
    ]);
    _updatePendingCount();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // Desktop: Sidebar + conteúdo
    // Mobile/Tablet: BottomNavigationBar + conteúdo
    // O ProviderHome (índice 0) NÃO tem BottomNavigationBar no mobile
    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                _buildDesktopSidebar(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            )
          : IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
      bottomNavigationBar: !isDesktop && _currentIndex != 0
          ? _buildBottomNavigationBar()
          : null,
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryCream,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: const Center(child: Icon(Icons.build_rounded, color: AppColors.primaryBlue, size: 50)),
            ),
            const SizedBox(height: 32),
            const Text('HoraExtra', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primaryCream)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryCream)),
            const SizedBox(height: 24),
            Text('Carregando...', style: TextStyle(color: AppColors.primaryCream.withOpacity(0.8), fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final count = _pendingRequestsCount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 2) _fetchPendingCount();
          });
        },
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.creamMedium,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: List.generate(
          _icons.length,
          (index) => NavigationDestination(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_icons[index], color: _currentIndex == index ? AppColors.primaryBlue : AppColors.blueLight),
                if (index == 2 && count > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: _titles[index],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    final count = _pendingRequestsCount;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: AppColors.creamDark.withOpacity(0.3), width: 1)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(2, 0))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.creamDark.withOpacity(0.3)))),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: AppColors.providerGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Icon(Icons.build_rounded, color: Colors.white, size: 22)),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HoraExtra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                    Text('Prestador', style: TextStyle(fontSize: 11, color: AppColors.blueMedium)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: List.generate(_icons.length, (index) => _buildNavItem(index)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.creamLight),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Versão 1.0.0', style: TextStyle(fontSize: 11, color: AppColors.blueLight)),
                OutlinedButton.icon(
                  onPressed: _showDesktopLogoutDialog,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sair'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _currentIndex == index;
    final icon = _icons[index];
    final label = _titles[index];
    final badgeCount = index == 2 ? _pendingRequestsCount : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ListTile(
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
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryBlue : AppColors.blueMedium,
              ),
            ),
            selected: isSelected,
            selectedTileColor: AppColors.creamMedium.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => setState(() {
              _currentIndex = index;
              if (index == 2) _fetchPendingCount();
            }),
          ),
          if (badgeCount > 0 && !isSelected)
            Positioned(
              left: 28,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDesktopLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Provider.of<AppProvider>(context, listen: false).logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}