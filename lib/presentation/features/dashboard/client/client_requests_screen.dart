// lib/presentation/features/dashboard/client/client_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/constants/app_text_styles.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';

class ClientRequestsScreen extends StatefulWidget {
  const ClientRequestsScreen({super.key});

  @override
  State<ClientRequestsScreen> createState() => _ClientRequestsScreenState();
}

class _ClientRequestsScreenState extends State<ClientRequestsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedFilter = 'all'; // all, pending, active, completed, cancelled

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar
          SliverAppBar(
            backgroundColor: theme.cardColor,
            elevation: 0,
            floating: true,
            pinned: true,
            title: Text(
              'Meus Pedidos',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                color: theme.colorScheme.onSurface,
                onPressed: () {
                  // TODO: Abrir filtros
                },
              ),
            ],
          ),

          // Filtros
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 40 : 20,
              20,
              isDesktop ? 40 : 20,
              16,
            ),
            sliver: SliverToBoxAdapter(
              child: _buildFilters(theme, isDesktop),
            ),
          ),

          // Lista de pedidos (mock)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 40 : 20,
              0,
              isDesktop ? 40 : 20,
              100,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildRequestCard(
                    theme,
                    isDesktop,
                    _getMockRequests()[index],
                  );
                },
                childCount: _getMockRequests().length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme, bool isDesktop) {
    final filters = [
      {'id': 'all', 'label': 'Todos', 'icon': Icons.apps_rounded},
      {'id': 'pending', 'label': 'Pendentes', 'icon': Icons.schedule_rounded},
      {'id': 'active', 'label': 'Em Andamento', 'icon': Icons.sync_rounded},
      {
        'id': 'completed',
        'label': 'Concluídos',
        'icon': Icons.check_circle_rounded
      },
      {'id': 'cancelled', 'label': 'Cancelados', 'icon': Icons.cancel_rounded},
    ];

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(filter['label'] as String),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['id'] as String;
                });
              },
              backgroundColor: theme.cardColor,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : theme.dividerColor.withOpacity(0.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
    ThemeData theme,
    bool isDesktop,
    Map<String, dynamic> request,
  ) {
    final status = request['status'] as String;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule_rounded;
        break;
      case 'active':
        statusColor = AppColors.info;
        statusIcon = Icons.sync_rounded;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = theme.disabledColor;
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: Abrir detalhes do pedido
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // Ícone do serviço
                    Container(
                      width: isDesktop ? 56 : 48,
                      height: isDesktop ? 56 : 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.8),
                            AppColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.cleaning_services_rounded,
                        color: Colors.white,
                        size: isDesktop ? 28 : 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['serviceName'] as String,
                            style: AppTextStyles.cardTitle(context).copyWith(
                              fontSize: isDesktop ? 17 : 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                request['date'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            request['statusLabel'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Prestador
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prestador',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.disabledColor,
                            ),
                          ),
                          Text(
                            request['providerName'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Preço
                    Text(
                      'MT ${request['price']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                // Ações (se aplicável)
                if (status == 'pending' || status == 'active')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        if (status == 'pending')
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // TODO: Cancelar pedido
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        if (status == 'active') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Chat com prestador
                              },
                              icon: const Icon(Icons.chat_bubble_outline,
                                  size: 18),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Ver detalhes
                              },
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 18),
                              label: const Text('Detalhes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMockRequests() {
    return [
      {
        'id': '1',
        'serviceName': 'Limpeza Residencial Completa',
        'date': '15 Fev 2026, 14:00',
        'providerName': 'João Silva',
        'price': '1,500.00',
        'status': 'active',
        'statusLabel': 'Em Andamento',
      },
      {
        'id': '2',
        'serviceName': 'Instalação Elétrica',
        'date': '14 Fev 2026, 10:00',
        'providerName': 'Maria Santos',
        'price': '2,000.00',
        'status': 'pending',
        'statusLabel': 'Pendente',
      },
      {
        'id': '3',
        'serviceName': 'Reparo Hidráulico',
        'date': '10 Fev 2026, 09:00',
        'providerName': 'Carlos Lima',
        'price': '1,200.00',
        'status': 'completed',
        'statusLabel': 'Concluído',
      },
      {
        'id': '4',
        'serviceName': 'Pintura de Ambientes',
        'date': '08 Fev 2026, 08:00',
        'providerName': 'Ana Costa',
        'price': '2,500.00',
        'status': 'cancelled',
        'statusLabel': 'Cancelado',
      },
    ];
  }
}
