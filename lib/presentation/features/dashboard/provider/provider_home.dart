// lib/presentation/features/dashboard/provider/provider_home.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import 'package:horaextra_app/presentation/features/map/provider_map_screen.dart';

class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  bool _isLoading = true;
  bool _isOnline = true;
  bool _isTogglingStatus = false;

  // Timer de stats — apenas stats, não pedidos pendentes
  Timer? _statsTimer;

  // Subscriptions WS
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupWsListeners();

    // Stats a cada 60s (não precisa de ser mais frequente)
    _statsTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).loadProviderStats();
      }
    });
  }

  Future<void> _initializeData() async {
    final ap = Provider.of<AppProvider>(context, listen: false);
    try {
      await Future.wait([
        ap.loadProviderStats(),
        ap.getProviderPendingRequests(),
      ]);
    } catch (e) {
      debugPrint('Erro ao carregar dados iniciais: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _setupWsListeners() {
    // Quando WS conecta, recarregar stats uma vez
    _subs.add(RealtimeWsService().connectionStatus.listen((connected) {
      if (!mounted) return;
      if (connected) {
        Provider.of<AppProvider>(context, listen: false).loadProviderStats();
      }
    }));

    // Novos pedidos chegam via WS — AppProvider já actualizado via setPendingRequestsFromWs
    _subs.add(RealtimeWsService().pendingRequests.listen((requests) {
      if (!mounted) return;
      Provider.of<AppProvider>(context, listen: false)
          .setPendingRequestsFromWs(requests);
      setState(() {});
    }));

    _subs.add(RealtimeWsService().newRequest.listen((data) {
      if (!mounted) return;
      // Recarregar pedidos quando chega novo pedido via WS
      Provider.of<AppProvider>(context, listen: false)
          .getProviderPendingRequests(forceRefresh: true);
    }));
  }

  // Alterna disponibilidade: persiste no backend (is_available) e só
  // depois propaga via WS. Se a chamada à API falhar, reverte o estado
  // visual e avisa o prestador — antes disto o toggle nunca chegava
  // a gravar no banco, por isso o prestador aparecia como online no
  // WS mas continuava invisível para os clientes.
  Future<void> _toggleOnlineStatus() async {
    if (_isTogglingStatus) return;
    final newStatus = !_isOnline;
    setState(() {
      _isOnline = newStatus;
      _isTogglingStatus = true;
    });
    try {
      await Provider.of<AppProvider>(context, listen: false)
          .updateProviderStatus(newStatus);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOnline = !newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar status: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline,
                  color: AppColors.primaryBlue),
              title: const Text('Meu Perfil',
                  style: TextStyle(color: AppColors.primaryBlue)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.providerOwnProfile);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.history_outlined, color: AppColors.info),
              title: const Text('Histórico',
                  style: TextStyle(color: AppColors.primaryBlue)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.providerHistory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppColors.textSecondary),
              title: const Text('Configurações',
                  style: TextStyle(color: AppColors.primaryBlue)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.settings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.info),
              title: const Text('Ajuda',
                  style: TextStyle(color: AppColors.primaryBlue)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.help);
              },
            ),
            const Divider(color: AppColors.border),
            ListTile(
              leading:
                  const Icon(Icons.logout_outlined, color: AppColors.error),
              title:
                  const Text('Sair', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Sair', style: TextStyle(color: AppColors.primaryBlue)),
        content: const Text('Tem certeza que deseja sair?',
            style: TextStyle(color: AppColors.blueMedium)),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.blueMedium)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Provider.of<AppProvider>(context, listen: false).logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
    final isMobile = size.width < 600;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mapa a tela inteira
          const ProviderMapScreen(),

          // Barra superior flutuante
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  isMobile ? 8 : 12,
                  isMobile ? 6 : 8,
                  isMobile ? 8 : 12,
                  0,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: isMobile ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.providerOwnProfile),
                      child: Row(
                        children: [
                          Container(
                            width: isMobile ? 36 : 40,
                            height: isMobile ? 36 : 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.providerGradient,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipOval(
                              child: user?.photoUrl != null &&
                                      user!.photoUrl!.isNotEmpty
                                  ? Image.network(
                                      user.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          user.name[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        user?.name[0].toUpperCase() ?? 'P',
                                        style: TextStyle(
                                          fontSize: isMobile ? 14 : 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Olá, ${user?.name.split(' ')[0] ?? 'Prestador'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _isOnline
                                            ? AppColors.success
                                            : Colors.grey.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isOnline ? 'Disponível' : 'Indisponível',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _isOnline
                                            ? AppColors.success
                                            : Colors.grey.shade400,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Botão de notificações com badge
                    Consumer<AppProvider>(
                      builder: (context, ap, _) {
                        final pendingCount = ap.pendingRequests.length;
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.providerNotifications),
                              child: Container(
                                padding: EdgeInsets.all(isMobile ? 7 : 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(isMobile ? 10 : 12),
                                ),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: isMobile ? 20 : 22,
                                ),
                              ),
                            ),
                            if (pendingCount > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    pendingCount > 9 ? '9+' : '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    SizedBox(width: isMobile ? 8 : 12),

                    // Menu
                    GestureDetector(
                      onTap: () => _showMenu(context),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 7 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(isMobile ? 10 : 12),
                        ),
                        child: Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: isMobile ? 20 : 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Indicador online/offline — reflete AGORA a disponibilidade real
          // do prestador (_isOnline, persistida no backend), não apenas se
          // o WebSocket está ligado.
          Positioned(
            top: isMobile ? 70 : 76,
            right: isMobile ? 8 : 12,
            child: GestureDetector(
              onTap: _isTogglingStatus ? null : _toggleOnlineStatus,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: _isOnline ? AppColors.success : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTogglingStatus)
                      SizedBox(
                        width: isMobile ? 9 : 10,
                        height: isMobile ? 9 : 10,
                        child: const CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      )
                    else
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
