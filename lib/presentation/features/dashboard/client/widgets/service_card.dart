// lib/presentation/features/dashboard/client/widgets/service_card.dart
// Redesign: sem ícones, visual limpo, moderno e intuitivo

import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/constants/app_sizes.dart';
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import '../../../requests/select_provider_screen.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final bool isDesktop;

  const ServiceCard({
    super.key,
    required this.service,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getServiceColor();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showServiceDetails(context),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha superior: categoria
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pílula de categoria colorida
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        service.categoryName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),

                // Nome do serviço
                Text(
                  service.name,
                  style: TextStyle(
                    fontSize: isDesktop ? 17 : 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Descrição curta
                Text(
                  service.description,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Rodapé: preço + seta
                Row(
                  children: [
                    // Preço
                    _buildTextBadge(
                      'MT ${service.price.toStringAsFixed(0)}',
                      AppColors.success,
                    ),
                    const Spacer(),
                    // CTA textual
                    Text(
                      'Ver detalhes →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
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

  Widget _buildTextBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _getServiceColor() {
    switch (service.categoryName.toLowerCase()) {
      case 'limpeza':
        return const Color(0xFF10B981);
      case 'elétrica':
        return const Color(0xFFF59E0B);
      case 'hidráulica':
        return const Color(0xFF3B82F6);
      case 'pintura':
        return const Color(0xFF8B5CF6);
      case 'jardinagem':
        return const Color(0xFF10B981);
      case 'montagem':
        return const Color(0xFFF59E0B);
      case 'marcenaria':
        return const Color(0xFF8B5CF6);
      case 'pets':
        return const Color(0xFFEC4899);
      default:
        return AppColors.primaryBlue;
    }
  }

  // ─── MODAL DE DETALHES ─────────────────────────────────────────────────────

  void _showServiceDetails(BuildContext context) {
    final color = _getServiceColor();
    final isMobile = MediaQuery.of(context).size.width <= 768;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Estado do modal vive aqui fora, para não ser reiniciado a cada
        // rebuild do StatefulBuilder.
        int selectedQuantity = 1;

        return StatefulBuilder(
          builder: (context, setState) {
            final size = MediaQuery.of(context).size;
            final maxWidth = size.width > 700 ? 520.0 : double.infinity;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: size.height * 0.9,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      // Scroll content
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Imagem / Banner
                                _buildBanner(color, isMobile),
                                const SizedBox(height: 20),

                                // Categoria
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    service.categoryName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Título
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryBlue,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Descrição
                                Text(
                                  service.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Preço — valor único e fixo do serviço
                                _buildPriceBlock(color),

                                // Quantidade (só para limpeza)
                                if (service.categoryName.toLowerCase() ==
                                    'limpeza') ...[
                                  const SizedBox(height: 16),
                                  _buildSectionLabel('Configurar pedido'),
                                  const SizedBox(height: 12),
                                  _buildQuantitySelector(
                                    selectedQuantity,
                                    (v) => setState(() => selectedQuantity = v),
                                  ),
                                ],
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Botões fixos
                      _buildActionButtons(
                        context,
                        selectedQuantity,
                        isMobile,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBanner(Color color, bool isMobile) {
    final imageUrl = ApiConfig.getFullImageUrl(service.imageUrl);
    final hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: isMobile ? 150 : 190,
        width: double.infinity,
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildColorBanner(color),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _buildColorBanner(color),
              )
            : _buildColorBanner(color),
      ),
    );
  }

  Widget _buildColorBanner(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.6)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        service.categoryName,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // Bloco de preço em destaque — comunica que o valor é fixo/único,
  // sem comparação entre prestadores.
  Widget _buildPriceBlock(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.10), color.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PREÇO DO SERVIÇO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.75),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'MT ${service.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Valor fixo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: AppColors.border),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector(int quantity, Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Quantidade',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (quantity > 1) onChanged(quantity - 1);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    quantity > 1 ? AppColors.primaryBlue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '−',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: quantity > 1 ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              quantity.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(quantity + 1),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                '+',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    int quantity,
    bool isMobile,
  ) {
    final totalPrice = service.price * quantity;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total estimado',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'MT ${totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Botões
          Row(
            children: [
              // Solicitar agora (outline) — pede a todos os prestadores online
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _solicitarAgora(context, quantity),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(
                        color: AppColors.primaryBlue, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Solicitar Agora',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Escolher prestador (filled)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppRoutes.selectProvider,
                      arguments: {
                        'service': service,
                        'quantity': quantity,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Escolher Prestador',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // "Solicitar Agora" a partir do card do serviço: fecha o modal e leva o
  // cliente direto para a tela de seleção de prestador, onde o botão
  // "Solicitar Agora" já notifica automaticamente todos os prestadores
  // online — mantendo a lógica de envio num único lugar.
  void _solicitarAgora(BuildContext context, int quantity) {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      AppRoutes.selectProvider,
      arguments: {
        'service': service,
        'quantity': quantity,
      },
    );
  }
}
