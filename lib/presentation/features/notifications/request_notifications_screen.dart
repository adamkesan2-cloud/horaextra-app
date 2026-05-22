// lib/presentation/features/notifications/request_notifications_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Melhorias:
//   • Aba "Histórico" com serviços concluídos e cancelados
//   • Cancelar solicitação pendente
//   • Agendamento visível no card
//   • Concluir serviço → regista no histórico
//   • Polling para web
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/data/models/request/service_request_model.dart';

class RequestNotificationsScreen extends StatefulWidget {
  const RequestNotificationsScreen({super.key});

  @override
  State<RequestNotificationsScreen> createState() =>
      _RequestNotificationsScreenState();
}

class _RequestNotificationsScreenState
    extends State<RequestNotificationsScreen>
    with TickerProviderStateMixin {
  bool _loading = false;
  Timer? _pollTimer;
  final List<StreamSubscription> _subs = [];
  bool _wsConnected = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _connectWebSocket();

    // Polling 5s
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _refresh(silent: true);
    });

    _subs.add(RealtimeWsService().connectionStatus.listen((status) {
      if (!mounted) return;
      setState(() => _wsConnected = status);
      if (status) _refresh(silent: true);
    }));

    _subs.add(RealtimeWsService().requestResponse.listen((data) {
      if (!mounted) return;
      final accepted = data['accepted'] == true;
      final completed = data['completed'] == true;
      final providerName = data['providerName']?.toString() ?? 'Prestador';
      if (completed) {
        _showSnack('Serviço concluído com sucesso!', AppColors.success);
        // Muda para aba Histórico
        _tabController.animateTo(2);
      } else {
        _showSnack(
          accepted
              ? '$providerName aceitou o seu pedido!'
              : '$providerName recusou o pedido.',
          accepted ? AppColors.success : AppColors.error,
        );
      }
      _refresh(silent: false);
    }));

    _subs.add(RealtimeWsService().serviceCompleted.listen((data) {
      if (!mounted) return;
      _refresh(silent: false);
      _tabController.animateTo(2);
    }));

    _subs.add(RealtimeWsService().newRequest.listen((_) {
      if (!mounted) return;
      _refresh(silent: true);
    }));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (final s in _subs) s.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null && user.role == 'client') {
      await RealtimeWsService().connect(
        userId: user.id,
        name: user.name,
        role: 'client',
        lat: -25.9692,
        lng: 32.5732,
        isOnline: true,
      );
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loading = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.loadClientRequests(forceRefresh: true);
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // Cancelar solicitação pendente
  Future<void> _cancelRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar solicitação',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
                fontSize: 16)),
        content: const Text(
            'Tem certeza que deseja cancelar esta solicitação?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não',
                  style: TextStyle(color: AppColors.primaryBlue))),
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
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.rejectRequest(requestId);
      _showSnack('Solicitação cancelada.', AppColors.textSecondary);
      await _refresh(silent: false);
      _tabController.animateTo(2); // Histórico
    } catch (e) {
      _showSnack('Erro ao cancelar: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Concluir serviço
  Future<void> _completeService(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Concluir serviço',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
                fontSize: 16)),
        content: const Text(
            'Confirme que o serviço foi concluído com sucesso.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.completeService(requestId);
      _showSnack(
          'Serviço concluído! Obrigado por usar HoraExtra.',
          AppColors.success);
      await _refresh(silent: false);
      _tabController.animateTo(2); // Move para Histórico
    } catch (e) {
      _showSnack('Erro ao concluir: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Consumer<AppProvider>(
      builder: (ctx, ap, _) {
        final all = ap.getClientRequestsList();

        final pending = all
            .where((r) =>
                r.status == 'pending' || r.status == 'providers_selected')
            .toList();
        final active = all
            .where((r) =>
                r.status == 'accepted' || r.status == 'in_progress')
            .toList();
        final history = all
            .where((r) =>
                r.status == 'completed' || r.status == 'cancelled')
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(pending.length),
          body: Column(
            children: [
              // Tab bar
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
                  unselectedLabelStyle:
                      const TextStyle(fontSize: 13),
                  tabs: [
                    Tab(text: 'Pendentes (${pending.length})'),
                    Tab(text: 'Ativos (${active.length})'),
                    Tab(text: 'Histórico (${history.length})'),
                  ],
                ),
              ),

              Expanded(
                child: _loading && all.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryBlue))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(pending, isDesktop,
                              emptyMsg: 'Nenhuma solicitação pendente',
                              showCancel: true),
                          _buildList(active, isDesktop,
                              emptyMsg: 'Nenhum serviço ativo',
                              showComplete: true),
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

  PreferredSizeWidget _buildAppBar(int pendingCount) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      title: Row(
        children: [
          const Text('Minhas Solicitações',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue)),
          if (pendingCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$pendingCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          // Status WS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (_wsConnected ? AppColors.success : AppColors.error)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: _wsConnected
                          ? AppColors.success
                          : AppColors.error,
                      shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(
                _wsConnected ? 'Online' : 'Polling',
                style: TextStyle(
                    fontSize: 10,
                    color: _wsConnected
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ],
      ),
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
    List<ServiceRequestModel> requests,
    bool isDesktop, {
    required String emptyMsg,
    bool showCancel = false,
    bool showComplete = false,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emptyMsg,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _refresh(silent: false),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue)),
              child: const Text('Atualizar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(silent: false),
      color: AppColors.primaryBlue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        itemCount: requests.length,
        itemBuilder: (_, i) => _buildCard(
          requests[i],
          isDesktop,
          showCancel: showCancel,
          showComplete: showComplete,
        ),
      ),
    );
  }

  Widget _buildHistoryList(
      List<ServiceRequestModel> history, bool isDesktop) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Nenhum histórico ainda',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue)),
            const SizedBox(height: 8),
            const Text(
                'Quando um serviço for concluído ou cancelado\naparece aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      itemCount: history.length,
      itemBuilder: (_, i) => _buildHistoryCard(history[i], isDesktop),
    );
  }

  Widget _buildCard(
    ServiceRequestModel r,
    bool isDesktop, {
    bool showCancel = false,
    bool showComplete = false,
  }) {
    final statusColor = _statusColor(r.status);
    final providerName = r.providerName ?? '';
    final address =
        r.clientAddress.isNotEmpty ? r.clientAddress : 'Maputo, Moçambique';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: statusColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 16 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.serviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.primaryBlue)),
                      const SizedBox(height: 2),
                      Text(_formatDate(r.createdAt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(_statusLabel(r.status),
                      style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),

            // Info
            Row(children: [
              Expanded(
                child: Text(address,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('MT ${r.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue)),
            ]),

            if (r.scheduledDate != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.info.withOpacity(0.2)),
                ),
                child: Text(
                  'Agendado: ${_formatDateFull(r.scheduledDate!)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],

            if (r.status == 'accepted' || r.status == 'in_progress') ...[
              const SizedBox(height: 6),
              Text(
                'Prestador: ${providerName.isNotEmpty ? providerName : 'Atribuído'}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 10),
            _buildStatusBox(r.status, providerName, statusColor),

            // Botões
            if (showCancel) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _cancelRequest(r.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar solicitação',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ] else if (showComplete) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showProviderContact(
                          providerName.isNotEmpty
                              ? providerName
                              : 'Prestador'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(
                            color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                      ),
                      child: const Text('Contactar',
                          style: TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _completeService(r.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Concluir Serviço',
                          style: TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ServiceRequestModel r, bool isDesktop) {
    final statusColor = _statusColor(r.status);
    final isCompleted = r.status == 'completed';

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.serviceName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue)),
                      Text(_formatDate(r.createdAt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(_statusLabel(r.status),
                      style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('MT ${r.price.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? AppColors.success
                          : AppColors.textSecondary)),
              if (r.providerName != null && r.providerName!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(r.providerName!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ],
            ]),
            if (r.scheduledDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Agendado: ${_formatDateFull(r.scheduledDate!)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.info),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 7, horizontal: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCompleted
                    ? 'Serviço concluído com sucesso'
                    : 'Solicitação cancelada',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBox(String status, String providerName,
      Color statusColor) {
    String message;
    if (status == 'providers_selected' || status == 'pending') {
      return Row(children: [
        const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.warning)),
        const SizedBox(width: 8),
        const Text('A aguardar resposta do prestador...',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w500)),
      ]);
    }
    switch (status) {
      case 'accepted':
        message =
            '${providerName.isNotEmpty ? providerName : 'Prestador'} aceitou! Está a caminho.';
        break;
      case 'in_progress':
        message = 'Serviço em andamento...';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Text(message,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor)),
    );
  }

  void _showProviderContact(String name) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.creamLight,
              child: Text(name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue)),
            ),
            const SizedBox(height: 12),
            Text(name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(
                          color: AppColors.primaryBlue)),
                  child: const Text('Fechar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white),
                  child: const Text('WhatsApp'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
      case 'providers_selected':
        return 'Pendente';
      case 'accepted':
        return 'Aceite';
      case 'in_progress':
        return 'Em andamento';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'accepted':
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'in_progress':
        return AppColors.primaryBlue;
      default:
        return AppColors.warning;
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Agora mesmo';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _formatDateFull(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        'às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}h';
  }
}