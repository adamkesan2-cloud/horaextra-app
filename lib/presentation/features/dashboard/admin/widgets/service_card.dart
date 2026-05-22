import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailable;

  const ServiceCard({
    super.key,
    required this.service,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ícone fixo
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.build,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),

            // Informações — Expanded garante que não vaza
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome + badge — Row interno com Expanded no nome
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StatusBadge(isAvailable: service.isAvailable),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Detalhes — texto composto simples, sem Row aninhado problemático
                  Text(
                    '${service.categoryName}  ·  '
                    '${service.price.toStringAsFixed(0)} MT  ·  '
                    '${_formatTime(service.estimatedTime)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // Ações — tamanho fixo, não causa overflow
            _ActionIcon(
              icon: Icons.edit_outlined,
              color: AppColors.primary,
              onPressed: onEdit,
            ),
            _ActionIcon(
              icon: Icons.delete_outline,
              color: AppColors.error,
              onPressed: onDelete,
            ),
            Transform.scale(
              scale: 0.7,
              alignment: Alignment.centerRight,
              child: Switch(
                value: service.isAvailable,
                onChanged: (_) => onToggleAvailable(),
                activeThumbColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isAvailable;
  const _StatusBadge({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAvailable
            ? AppColors.success.withOpacity(0.1)
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAvailable ? 'Ativo' : 'Inativo',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isAvailable ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}
