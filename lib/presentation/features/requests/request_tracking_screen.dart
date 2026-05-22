// lib/presentation/features/requests/request_tracking_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Ecrã de acompanhamento — corrigido:
//   • Bad state: No element → indexWhere seguro
//   • Navega para mapa ao aceitar
//   • Estado visual de cada prestador em tempo real
//   • Adicionado suporte para quantity
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/data/models/provider/provider_selection_model.dart';
import 'package:horaextra_app/presentation/features/map/client_map_screen.dart';
import 'package:horaextra_app/presentation/features/profile/view/provider_profile_screen.dart';
import 'package:provider/provider.dart';

class RequestTrackingScreen extends StatefulWidget {
  final String serviceName;
  final List<ProviderSelectionModel> selectedProviders;
  final bool isUrgent;
  final DateTime? scheduledDate;
  final String? requestId;
  final int quantity; // ✅ Adicionado quantity

  const RequestTrackingScreen({
    super.key,
    required this.serviceName,
    required this.selectedProviders,
    this.isUrgent = false,
    this.scheduledDate,
    this.requestId,
    this.quantity = 1, // ✅ Valor padrão
  });

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

enum _ProviderStatus { pending, accepted, rejected }

class _RequestTrackingScreenState extends State<RequestTrackingScreen>
    with TickerProviderStateMixin {
  final Map<String, _ProviderStatus> _statuses = {};
  String? _acceptedProviderId;
  String? _acceptedProviderName;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final List<StreamSubscription> _wsSubs = [];
  bool _navigatedToMap = false;

  @override
  void initState() {
    super.initState();

    for (final p in widget.selectedProviders) {
      _statuses[p.id] = _ProviderStatus.pending;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenToWs();
    _checkExistingAccepted();
  }

  /// Verifica se já existe um pedido aceite (sem usar firstWhere inseguro)
  void _checkExistingAccepted() async {
    if (widget.requestId == null) return;
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      final requests = ap.getClientRequestsList();
      if (requests.isEmpty) return;

      // Busca segura por índice
      final idx = requests.indexWhere((r) => r.id == widget.requestId);
      if (idx < 0) return;
      final request = requests[idx];

      if (request.status == 'accepted' || request.status == 'in_progress') {
        if (request.providerName != null && request.providerName!.isNotEmpty) {
          if (mounted) {
            setState(() {
              _acceptedProviderName = request.providerName;
              _acceptedProviderId = request.providerId;
            });
          }
          _navigateToMapAfterDelay();
        }
      }
    } catch (e) {
      debugPrint('Erro _checkExistingAccepted: $e');
    }
  }

  void _listenToWs() {
    _wsSubs.add(RealtimeWsService().requestResponse.listen((data) {
      if (!mounted) return;

      final incomingRequestId = data['requestId']?.toString() ?? '';
      if (widget.requestId != null &&
          incomingRequestId.isNotEmpty &&
          incomingRequestId != widget.requestId) return;

      final accepted = data['accepted'] == true;
      final providerId = data['providerId']?.toString() ?? '';
      final providerName = data['providerName']?.toString() ?? 'Prestador';

      setState(() {
        if (providerId.isNotEmpty && _statuses.containsKey(providerId)) {
          _statuses[providerId] =
              accepted ? _ProviderStatus.accepted : _ProviderStatus.rejected;
          if (accepted) {
            _acceptedProviderId = providerId;
            _acceptedProviderName = providerName;
          }
        } else {
          // Fallback: aplica ao primeiro pendente
          final pendingKey = _statuses.entries
              .where((e) => e.value == _ProviderStatus.pending)
              .map((e) => e.key)
              .firstOrNull;
          if (pendingKey != null) {
            _statuses[pendingKey] =
                accepted ? _ProviderStatus.accepted : _ProviderStatus.rejected;
            if (accepted) {
              _acceptedProviderName = providerName;
              _acceptedProviderId = pendingKey;
            }
          }
        }
      });

      if (accepted) {
        _showAcceptedBanner(providerName);
        _navigateToMapAfterDelay();
      }
    }));

    _wsSubs.add(RealtimeWsService().serviceCompleted.listen((data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Serviço concluído com sucesso!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }));
  }

  void _navigateToMapAfterDelay() {
    if (_navigatedToMap) return;
    _navigatedToMap = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClientMapScreen(
              requestId: widget.requestId,
              providerId: _acceptedProviderId,
              providerName: _acceptedProviderName,
            ),
          ),
        );
      }
    });
  }

  void _showAcceptedBanner(String providerName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$providerName aceitou o pedido! A redirecionar para o mapa... 🗺️',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  @override
  void dispose() {
    for (final s in _wsSubs) s.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  int get _pendingCount =>
      _statuses.values.where((s) => s == _ProviderStatus.pending).length;
  int get _acceptedCount =>
      _statuses.values.where((s) => s == _ProviderStatus.accepted).length;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final hasAccepted = _acceptedProviderName != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.primaryBlue),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: const Text('Acompanhar Solicitação',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.creamDark, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(isDesktop, hasAccepted),
            const SizedBox(height: 24),
            if (hasAccepted) ...[
              _buildAcceptedCard(isDesktop),
              const SizedBox(height: 24),
            ],
            Text('Respostas dos Prestadores',
                style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue)),
            const SizedBox(height: 12),
            ...widget.selectedProviders
                .map((p) => _buildProviderCard(p, isDesktop)),
            const SizedBox(height: 20),
            if (!hasAccepted) _buildWaitingMessage(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(bool isDesktop, bool hasAccepted) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withOpacity(0.9),
            AppColors.primaryBlue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Solicitação Enviada!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          if (widget.isUrgent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt, color: Colors.white, size: 12),
                SizedBox(width: 2),
                Text('URGENTE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Text(widget.serviceName,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isDesktop ? 15 : 14)),
        if (widget.quantity > 1) ...[
          const SizedBox(height: 4),
          Text('📦 Quantidade: ${widget.quantity}x',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: isDesktop ? 14 : 13)),
        ],
        if (widget.scheduledDate != null) ...[
          const SizedBox(height: 4),
          Text('📅 ${_formatDate(widget.scheduledDate!)}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: isDesktop ? 14 : 13)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          _counter('${widget.selectedProviders.length}', 'Enviados',
              Colors.white, isDesktop),
          const SizedBox(width: 16),
          _counter(
              '$_acceptedCount', 'Aceites', const Color(0xFF81C995), isDesktop),
          const SizedBox(width: 16),
          _counter('$_pendingCount', 'Aguardando',
              Colors.white.withOpacity(0.7), isDesktop),
        ]),
        if (hasAccepted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.map_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_acceptedProviderName aceitou! A redirecionar para o mapa...',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _counter(String value, String label, Color color, bool isDesktop) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: isDesktop ? 24 : 22)),
      Text(label,
          style: TextStyle(
              color: color.withOpacity(0.8), fontSize: isDesktop ? 13 : 12)),
    ]);
  }

  Widget _buildAcceptedCard(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.check_circle,
              color: AppColors.success, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pedido Aceito!',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.success)),
            Text('$_acceptedProviderName está a caminho',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.blueMedium)),
            const SizedBox(height: 6),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 30),
              builder: (_, double v, __) => LinearProgressIndicator(
                  value: v,
                  backgroundColor: Colors.grey[200],
                  color: AppColors.success),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildWaitingMessage(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, __) => Opacity(
            opacity: _pulseAnimation.value,
            child: const Icon(Icons.hourglass_empty,
                color: AppColors.warning, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Aguardando resposta',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
            const SizedBox(height: 3),
            Text(
              'Os prestadores foram notificados. Será redirecionado para o mapa assim que alguém aceitar.',
              style: TextStyle(fontSize: 12, color: AppColors.blueMedium),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildProviderCard(ProviderSelectionModel provider, bool isDesktop) {
    final status = _statuses[provider.id] ?? _ProviderStatus.pending;
    final isAccepted = status == _ProviderStatus.accepted;
    // ✅ Calcular preço total com quantidade
    final totalPrice = provider.price * widget.quantity;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case _ProviderStatus.pending:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_empty_rounded;
        statusLabel = 'Aguardando resposta...';
        break;
      case _ProviderStatus.accepted:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Aceito! A caminho 🚀';
        break;
      case _ProviderStatus.rejected:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Recusado';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.all(isDesktop ? 16 : 14),
          child: Row(children: [
            Stack(children: [
              Container(
                width: isDesktop ? 56 : 50,
                height: isDesktop ? 56 : 50,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.providerGradient),
                child: Center(
                  child: Text(
                    provider.name.isNotEmpty
                        ? provider.name[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2)),
                  child: Icon(statusIcon, color: AppColors.white, size: 9),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isDesktop ? 16 : 15,
                            color: AppColors.primaryBlue)),
                    const SizedBox(height: 2),
                    Text(
                      '⭐ ${provider.rating} · ${provider.distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                          fontSize: isDesktop ? 13 : 12,
                          color: AppColors.blueMedium),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '💰 MT ${totalPrice.toStringAsFixed(0)}${widget.quantity > 1 ? ' (${widget.quantity}x ${provider.price.toStringAsFixed(0)} MT)' : ''}',
                      style: TextStyle(
                          fontSize: isDesktop ? 13 : 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success),
                    ),
                    const SizedBox(height: 6),
                    if (status == _ProviderStatus.pending)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, __) => Opacity(
                          opacity: _pulseAnimation.value,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(statusLabel,
                                style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      )
                    else
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusLabel,
                            style: TextStyle(
                                fontSize: isDesktop ? 13 : 12,
                                color: statusColor,
                                fontWeight: FontWeight.w700)),
                      ]),
                  ]),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              color: AppColors.primaryBlue,
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ProviderProfileScreen.fromProvider(provider))),
            ),
          ]),
        ),
        if (isAccepted)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14)),
            ),
            child: Row(children: [
              const Icon(Icons.directions_car_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text('Tempo estimado: ~${(provider.distance * 4).round()} min',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat em breve 💬'))),
                icon: const Icon(Icons.chat_bubble_outline,
                    size: 14, color: AppColors.success),
                label: const Text('Chat',
                    style: TextStyle(color: AppColors.success, fontSize: 13)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ]),
          ),
      ]),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
