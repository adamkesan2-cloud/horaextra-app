// lib/presentation/features/notifications/provider_notifications_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/presentation/features/map/provider_map_screen.dart';

class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  State<ProviderNotificationsScreen> createState() =>
      _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState
    extends State<ProviderNotificationsScreen> with TickerProviderStateMixin {
  bool _loading = false;

  // Polling de fallback: só activo se WS não estiver conectado
  Timer? _fallbackPollTimer;
  bool _wsConnected = false;

  final List<StreamSubscription> _subs = [];
  late TabController _tabController;

  String? _processingRequestId;
  final Set<String> _processingRequestIds = {};

  // IDs já vistos para não mostrar banner duplicado
  final Set<String> _seenRequestIds = {};

  AppProvider? _appProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _appProvider = Provider.of<AppProvider>(context, listen: false);
      _appProvider!.addListener(_onProviderChanged);
      await _connectWebSocket(); // ✅ NOVO — este ecrã já não depende do mapa
      _setupWsListeners();       // sempre, web ou nativo
      _refresh();
    });
  }

  // ✅ NOVO — liga o WS por conta própria, tal como o ecrã do cliente já faz.
  // Assim as notificações funcionam mesmo que o prestador nunca tenha
  // aberto o ecrã do mapa nesta sessão.
  Future<void> _connectWebSocket() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    // Já conectado (ex: veio do mapa)? não reconecta de novo.
    if (RealtimeWsService().isConnected) return;

    final token = await authProvider.getToken() ?? '';
    await RealtimeWsService().connect(
      userId: user.id,
      name: user.name,
      role: 'provider',
      token: token,
      isOnline: true,
    );
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  // ── WebSocket — funciona em web E nativo ────────────────────────────────
  void _setupWsListeners() {
    _subs.add(RealtimeWsService().connectionStatus.listen((connected) {
      if (!mounted) return;
      final wasConnected = _wsConnected;
      setState(() => _wsConnected = connected);

      if (connected) {
        // Acabou de conectar — recarregar uma vez
        if (!wasConnected) _refresh(silent: true);
        // Parar polling de fallback
        _fallbackPollTimer?.cancel();
        _fallbackPollTimer = null;
      } else {
        // WS caiu — activar polling de fallback a cada 10s
        _startFallbackPolling();
      }
    }));

    // Snapshot inicial de pedidos pendentes (enviado pelo servidor ao conectar)
    _subs.add(RealtimeWsService().pendingRequests.listen((requests) {
      if (!mounted) return;
      _appProvider?.setPendingRequestsFromWs(requests);
      _checkForNewRequests();
      if (mounted) setState(() {});
    }));

    // Novo pedido em tempo real
    _subs.add(RealtimeWsService().newRequest.listen((data) {
      if (!mounted) return;
      _showNewRequestBanner(data);
      _refresh(silent: true);
      HapticFeedback.heavyImpact();
    }));
  }

  void _startFallbackPolling() {
    if (_fallbackPollTimer != null) return; // já activo
    debugPrint('⚠️ WS offline — activando polling de fallback (10s)');
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (_wsConnected) {
        // WS voltou — parar polling
        _fallbackPollTimer?.cancel();
        _fallbackPollTimer = null;
        return;
      }
      _refresh(silent: true);
    });
  }

  void _checkForNewRequests() {
    final ap = _appProvider;
    if (ap == null) return;
    for (final req in ap.getPendingRequests()) {
      final id = req['id']?.toString();
      if (id != null && !_seenRequestIds.contains(id)) {
        _seenRequestIds.add(id);
        _showNewRequestBannerFromRequest(req);
      }
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loading = true);
    try {
      final ap = _appProvider ?? Provider.of<AppProvider>(context, listen: false);
      await ap.getProviderPendingRequests(forceRefresh: true);
      _checkForNewRequests();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Erro ao actualizar: $e');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  // ── Banners ────────────────────────────────────────────────────────────────

  void _showNewRequestBannerFromRequest(Map<String, dynamic> request) {
    if (!mounted) return;
    final clientName  = request['client_name']?.toString()  ?? 'Cliente';
    final serviceName = request['service_name']?.toString() ?? 'Serviço';
    final isUrgent    = request['is_urgent'] == true;
    _showBanner(
      title: isUrgent ? 'PEDIDO URGENTE!' : 'NOVO PEDIDO!',
      body: '$clientName solicitou: $serviceName',
      color: isUrgent ? AppColors.error : AppColors.warning,
    );
  }

  void _showNewRequestBanner(Map<String, dynamic> data) {
    if (!mounted) return;
    final clientName  = data['clientName']?.toString()  ?? 'Cliente';
    final serviceName = data['serviceName']?.toString() ?? 'Serviço';
    final isUrgent    = data['isUrgent'] == true;
    _showBanner(
      title: isUrgent ? 'PEDIDO URGENTE!' : 'NOVO PEDIDO!',
      body: '$clientName solicitou: $serviceName',
      color: isUrgent ? AppColors.error : AppColors.warning,
    );
  }

  void _showBanner({
    required String title,
    required String body,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(body,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
      backgroundColor: color,
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(12),
      action: SnackBarAction(
        label: 'VER',
        textColor: Colors.white,
        onPressed: () => _tabController.animateTo(0),
      ),
    ));
  }

  // ── Acções ─────────────────────────────────────────────────────────────────

  Future<void> _accept(
      String requestId, Map<String, dynamic> request, AppProvider ap) async {
    if (requestId.isEmpty || _processingRequestIds.contains(requestId)) return;
    setState(() {
      _processingRequestId = requestId;
      _processingRequestIds.add(requestId);
    });
    try {
      await ap.acceptRequest(requestId);
      await Future.delayed(const Duration(milliseconds: 500));
      final stillPending =
          ap.getPendingRequests().any((r) => r['id'] == requestId);
      if (stillPending) {
        _showSnack(
            'Pedido pode já ter sido aceite por outro prestador',
            AppColors.warning);
        return;
      }
      RealtimeWsService().respondToRequest(requestId, true);
      _showSnack('Pedido aceite! A caminho do cliente.', AppColors.success);
      await _refresh(silent: false);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderMapScreen(requestId: requestId),
          ),
        );
      }
    } catch (e) {
      _showSnack('Erro ao aceitar: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestId = null;
          _processingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _reject(String requestId, AppProvider ap) async {
    if (requestId.isEmpty || _processingRequestIds.contains(requestId)) return;
    setState(() {
      _processingRequestId = requestId;
      _processingRequestIds.add(requestId);
    });
    try {
      await ap.rejectRequest(requestId);
      RealtimeWsService().respondToRequest(requestId, false);
      _showSnack('Pedido recusado.', AppColors.error);
      await _refresh(silent: false);
    } catch (e) {
      _showSnack('Erro: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestId = null;
          _processingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _cancelAccepted(String requestId, AppProvider ap) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar serviço',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
        content: const Text(
            'Tem certeza que deseja cancelar este serviço aceite?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _reject(requestId, ap);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Normalização ───────────────────────────────────────────────────────────

  Map<String, dynamic> _normalize(dynamic raw) {
    final r = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final service = r['service'] is Map
        ? Map<String, dynamic>.from(r['service'] as Map)
        : <String, dynamic>{};
    final client = r['client'] is Map
        ? Map<String, dynamic>.from(r['client'] as Map)
        : <String, dynamic>{};
    final loc = r['location'] is Map
        ? Map<String, dynamic>.from(r['location'] as Map)
        : <String, dynamic>{};
    final meta = r['metadata'] is Map
        ? Map<String, dynamic>.from(r['metadata'] as Map)
        : <String, dynamic>{};

    return {
      'id': r['id']?.toString() ?? '',
      'service_name': service['name']?.toString() ??
          meta['service_name']?.toString() ??
          r['serviceName']?.toString() ??
          r['service_name']?.toString() ??
          'Serviço',
      'client_name': client['name']?.toString() ??
          r['clientName']?.toString() ??
          meta['client_name']?.toString() ??
          r['client_name']?.toString() ??
          'Cliente',
      'address': loc['address']?.toString() ?? 'Maputo, Moçambique',
      'latitude':  (loc['latitude']  as num?)?.toDouble() ?? -25.9692,
      'longitude': (loc['longitude'] as num?)?.toDouble() ??  32.5732,
      'budget': _toNum(r['budget'] ?? r['price'] ?? service['price'] ?? 0),
      'status': r['status']?.toString() ?? 'pending',
      'created_at': r['createdAt'] ?? r['created_at'],
      'observations': r['observations']?.toString() ?? '',
      'is_urgent': r['is_urgent'] == true || r['urgent'] == true,
      'scheduled_date': r['scheduled_date'] ?? r['scheduledDate'],
    };
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  void dispose() {
    _fallbackPollTimer?.cancel();
    for (final s in _subs) s.cancel();
    _tabController.dispose();
    _appProvider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Consumer<AppProvider>(
      builder: (context, ap, _) {
        final rawList  = ap.getPendingRequests();
        final requests = rawList.map(_normalize).toList();

        final pending = requests
            .where((r) =>
                r['status'] == 'pending' || r['status'] == 'providers_selected')
            .toList();
        final inProgress = requests
            .where((r) =>
                r['status'] == 'accepted' || r['status'] == 'in_progress')
            .toList();
        final history = requests
            .where((r) =>
                r['status'] == 'completed' || r['status'] == 'cancelled')
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(pending.length),
          body: Column(
            children: [
              // Barra de status WS
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                color: AppColors.white,
                child: Row(
                  children: [
                    _statusChip(),
                    const Spacer(),
                    TextButton(
                      onPressed:
                          _loading ? null : () => _refresh(silent: false),
                      child: Text(
                        _loading ? 'A actualizar...' : 'Actualizar',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // Abas
              Container(
                color: AppColors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryBlue,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: [
                    Tab(text: 'Pendentes (${pending.length})'),
                    Tab(text: 'Ativos (${inProgress.length})'),
                    Tab(text: 'Histórico (${history.length})'),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(pending, ap,
                        isPending: true, isDesktop: isDesktop),
                    _buildList(inProgress, ap,
                        isPending: false, isInProgress: true, isDesktop: isDesktop),
                    _buildHistoryList(history, isDesktop),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip() {
    final color = _wsConnected ? AppColors.success : AppColors.warning;
    final label = _wsConnected ? 'Tempo real · WS' : 'Polling 10s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar(int pendingCount) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      title: Row(children: [
        const Text('Solicitações',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue)),
        if (pendingCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10)),
            child: Text('$pendingCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1)),
      actions: [
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryBlue)))
        else
          IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.primaryBlue),
              onPressed: () => _refresh(silent: false)),
      ],
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> requests,
    AppProvider ap, {
    required bool isPending,
    bool isInProgress = false,
    required bool isDesktop,
  }) {
    if (requests.isEmpty) {
      return _buildEmpty(
          isPending ? 'Nenhum pedido pendente' : 'Nenhum serviço ativo');
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(silent: false),
      color: AppColors.primaryBlue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        itemCount: requests.length,
        itemBuilder: (_, i) => _buildCard(
          requests[i], ap,
          isPending: isPending,
          isInProgress: isInProgress,
          isDesktop: isDesktop,
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> history, bool isDesktop) {
    if (history.isEmpty) return _buildEmpty('Nenhum histórico ainda');
    return RefreshIndicator(
      onRefresh: () => _refresh(silent: false),
      color: AppColors.primaryBlue,
      child: ListView.builder(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        itemCount: history.length,
        itemBuilder: (_, i) => _buildHistoryCard(history[i], isDesktop),
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> r,
    AppProvider ap, {
    required bool isPending,
    bool isInProgress = false,
    required bool isDesktop,
  }) {
    final requestId   = r['id'] as String;
    final isUrgent    = r['is_urgent'] == true;
    final budget      = r['budget'] as num;
    final clientName  = r['client_name'] as String;
    final serviceName = r['service_name'] as String;
    final address     = r['address'] as String;
    final observations = r['observations'] as String;
    final status      = r['status'] as String;
    final scheduledDate = r['scheduled_date'];
    final isProcessing  = _processingRequestId == requestId;

    Color borderColor;
    if (isPending)      borderColor = isUrgent ? AppColors.error : AppColors.warning;
    else if (isInProgress) borderColor = AppColors.primaryBlue;
    else                borderColor = AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 16 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.primaryBlue)),
                      const SizedBox(height: 3),
                      Text(clientName,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Row(children: [
                  if (isUrgent && isPending) _chip('URGENTE', AppColors.error),
                  const SizedBox(width: 6),
                  _chip(_statusLabel(status), _statusColor(status)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12, runSpacing: 6,
              children: [
                _infoText('MT ${budget.toStringAsFixed(0)}', color: AppColors.success),
                _infoText(address),
                _infoText(_formatDate(r['created_at'])),
                if (scheduledDate != null)
                  _infoText('Agendado: ${_formatDateFull(scheduledDate)}',
                      color: AppColors.info),
              ],
            ),
            if (observations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.creamLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(observations,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _statusColor(status).withOpacity(0.25)),
              ),
              child: Text(
                _statusMessage(status, clientName),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status)),
              ),
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : () => _reject(requestId, ap),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Recusar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        isProcessing ? null : () => _accept(requestId, r, ap),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Aceitar Serviço',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ] else if (isInProgress) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _cancelAccepted(requestId, ap),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProviderMapScreen(requestId: requestId),
                              ),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Ver no Mapa',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> r, bool isDesktop) {
    final status      = r['status'] as String;
    final serviceName = r['service_name'] as String;
    final clientName  = r['client_name'] as String;
    final budget      = r['budget'] as num;
    final isCompleted = status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serviceName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue)),
                    Text(clientName,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _chip(_statusLabel(status), _statusColor(status)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _infoText('MT ${budget.toStringAsFixed(0)}',
                  color: isCompleted
                      ? AppColors.success
                      : AppColors.textSecondary),
              const SizedBox(width: 16),
              _infoText(_formatDate(r['created_at'])),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCompleted
                    ? 'Serviço concluído com sucesso'
                    : 'Solicitação cancelada',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _infoText(String text, {Color? color}) => Text(text,
      style: TextStyle(
          fontSize: 12,
          color: color ?? AppColors.textSecondary,
          fontWeight:
              color != null ? FontWeight.w600 : FontWeight.w400));

  Widget _buildEmpty(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _refresh(silent: false),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue)),
              child: const Text('Verificar agora'),
            ),
          ],
        ),
      );

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
      case 'providers_selected': return 'Pendente';
      case 'accepted':           return 'Aceite';
      case 'in_progress':        return 'Em andamento';
      case 'completed':          return 'Concluído';
      case 'cancelled':          return 'Cancelado';
      default:                   return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'accepted':
      case 'completed':   return AppColors.success;
      case 'cancelled':   return AppColors.error;
      case 'in_progress': return AppColors.primaryBlue;
      default:            return AppColors.warning;
    }
  }

  String _statusMessage(String status, String clientName) {
    switch (status) {
      case 'pending':
      case 'providers_selected': return 'Aguardando sua resposta';
      case 'accepted':           return 'Pedido aceite — a caminho de $clientName';
      case 'in_progress':        return 'Serviço em andamento';
      case 'completed':          return 'Serviço concluído';
      case 'cancelled':          return 'Pedido cancelado';
      default:                   return status;
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    final dt = d is DateTime ? d : DateTime.tryParse(d.toString());
    if (dt == null) return d.toString();
    final diff = DateTime.now().difference(dt).abs();
    if (diff.inMinutes < 1)  return 'Agora mesmo';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Há ${diff.inHours}h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  String _formatDateFull(dynamic d) {
    if (d == null) return '';
    final dt = d is DateTime ? d : DateTime.tryParse(d.toString());
    if (dt == null) return d.toString();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        'às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}h';
  }
}