// lib/presentation/features/dashboard/provider/provider_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/widgets/pending_request_card.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';

class ProviderRequestsScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onRequestAccepted;
  final bool hasNewRequest;
  final VoidCallback? onNotificationCleared;

  const ProviderRequestsScreen({
    super.key,
    this.onRequestAccepted,
    this.hasNewRequest = false,
    this.onNotificationCleared,
  });

  @override
  State<ProviderRequestsScreen> createState() => _ProviderRequestsScreenState();
}

class _ProviderRequestsScreenState extends State<ProviderRequestsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.hasNewRequest && widget.onNotificationCleared != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onNotificationCleared!();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final pendingRequests = provider.getPendingRequests();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pedidos Pendentes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (pendingRequests.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => provider.notifyListeners(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => provider.notifyListeners(),
        color: AppColors.primary,
        child: pendingRequests.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height - 100,
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Nenhum pedido pendente',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Quando houver novos pedidos,\neles aparecerão aqui',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pendingRequests.length,
                itemBuilder: (context, index) {
                  final request = pendingRequests[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PendingRequestCard(
                      request: request,
                      onAccept: () {
                        provider.acceptRequest(request['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Pedido de ${request['client_name']} aceito!'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onReject: () {
                        provider.rejectRequest(request['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Pedido de ${request['client_name']} rejeitado'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onTap: () {
                        // Função vazia para compatibilidade
                        // O card já não usa mais, mas mantemos para não quebrar
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
