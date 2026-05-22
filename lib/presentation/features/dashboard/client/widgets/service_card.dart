// lib/presentation/features/dashboard/client/widgets/service_card.dart
// Redesign: sem ícones, visual limpo e intuitivo

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
                // Linha superior: categoria + rating
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
                    // Rating em texto puro
                    Text(
                      '★ ${service.rating.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
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

                // Rodapé: preço + tempo + seta
                Row(
                  children: [
                    // Preço
                    _buildTextBadge(
                      'MT ${service.price.toStringAsFixed(0)}',
                      AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    // Duração
                    _buildTextBadge(
                      _formatTime(service.estimatedTime),
                      AppColors.info,
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

  String _formatTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}min';
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          DateTime? selectedDate;
          final observationsController = TextEditingController();
          bool isUrgent = false;
          int selectedQuantity = 1;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

                          // Título + rating
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryBlue,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '★ ${service.rating.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  Text(
                                    '${service.reviewCount} avaliações',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

                          // Preço e duração lado a lado
                          Row(
                            children: [
                              Expanded(child: _buildInfoBlock('Preço', 'MT ${service.price.toStringAsFixed(0)}', AppColors.success)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildInfoBlock('Duração', _formatTime(service.estimatedTime), AppColors.info)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Divisor com rótulo
                          _buildSectionLabel('Configurar pedido'),
                          const SizedBox(height: 12),

                          // Quantidade (só para limpeza)
                          if (service.categoryName.toLowerCase() == 'limpeza') ...[
                            _buildQuantitySelector(
                              selectedQuantity,
                              (v) => setState(() => selectedQuantity = v),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Urgência
                          _buildUrgencyToggle(
                            isUrgent,
                            (v) => setState(() => isUrgent = v ?? false),
                          ),
                          const SizedBox(height: 12),

                          // Agendamento
                          _buildScheduleField(
                            context,
                            selectedDate,
                            (d) => setState(() => selectedDate = d),
                          ),
                          const SizedBox(height: 12),

                          // Observações
                          _buildObservationsField(observationsController),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botões fixos
                _buildActionButtons(
                  context,
                  selectedDate,
                  observationsController.text,
                  isUrgent,
                  selectedQuantity,
                  isMobile,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBanner(Color color, bool isMobile) {
    final imageUrl = ApiConfig.getFullImageUrl(service.imageUrl);
    final hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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

  Widget _buildInfoBlock(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
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
        borderRadius: BorderRadius.circular(12),
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
                color: quantity > 1
                    ? AppColors.primaryBlue
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(8),
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

  Widget _buildUrgencyToggle(bool isUrgent, Function(bool?) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!isUrgent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUrgent
              ? AppColors.warning.withOpacity(0.08)
              : AppColors.creamLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUrgent ? AppColors.warning : AppColors.border,
            width: isUrgent ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Serviço Urgente',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isUrgent
                          ? AppColors.warning
                          : AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Prioridade no atendimento — taxa adicional de 20%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Switch visual sem ícone
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color:
                    isUrgent ? AppColors.warning : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: isUrgent
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              padding: const EdgeInsets.all(3),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleField(
    BuildContext context,
    DateTime? selectedDate,
    Function(DateTime?) onSelected,
  ) {
    return GestureDetector(
      onTap: () async => _selectDateTime(context, onSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selectedDate != null
              ? AppColors.primaryBlue.withOpacity(0.05)
              : AppColors.creamLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedDate != null
                ? AppColors.primaryBlue
                : AppColors.border,
            width: selectedDate != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedDate != null ? 'Agendado para' : 'Agendar serviço',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selectedDate != null
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (selectedDate != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatDateTime(selectedDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Toque para escolher data e hora',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              selectedDate != null ? 'Alterar' : 'Escolher →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime(
    BuildContext context,
    Function(DateTime?) onSelected,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
        ),
        child: child!,
      ),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        ),
      );
      if (time != null) {
        onSelected(DateTime(
            date.year, date.month, date.day, time.hour, time.minute));
      }
    }
  }

  Widget _buildObservationsField(TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.primaryBlue,
      ),
      decoration: InputDecoration(
        hintText: 'Observações adicionais (opcional)',
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.creamLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    DateTime? scheduledDate,
    String observations,
    bool isUrgent,
    int quantity,
    bool isMobile,
  ) {
    final totalPrice = service.price * quantity * (isUrgent ? 1.2 : 1);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'MT ${totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  if (isUrgent)
                    const Text(
                      'taxa de urgência incluída (+20%)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Botões
          Row(
            children: [
              // Solicitar agora (outline)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _solicitarAgora(
                    context,
                    scheduledDate,
                    observations,
                    isUrgent,
                    quantity,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side:
                        const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectProviderScreen(
                          service: service,
                          scheduledDate: scheduledDate,
                          observations:
                              observations.isNotEmpty ? observations : null,
                          isUrgent: isUrgent,
                          quantity: quantity,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    scheduledDate != null ? 'Agendar' : 'Escolher Prestador',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _solicitarAgora(
    BuildContext context,
    DateTime? scheduledDate,
    String observations,
    bool isUrgent,
    int quantity,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUrgent
                ? 'Solicitação urgente enviada! Um prestador entrará em contato.'
                : 'Solicitação enviada! Em breve um prestador entrará em contato.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: isUrgent ? AppColors.warning : AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _formatDateTime(DateTime date) {
    final days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} às '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}h';
  }
}