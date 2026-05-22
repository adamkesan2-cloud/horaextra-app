// lib/presentation/features/dashboard/admin/widgets/category_card.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/constants/app_sizes.dart';
import 'package:horaextra_app/core/utils/image_helper.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    final cardHeight = isDesktop ? 280.0 : (isSmallScreen ? 200.0 : 240.0);
    final iconSize = isDesktop ? AppSizes.iconXXL : AppSizes.iconXL;
    final titleSize = isDesktop
        ? AppSizes.fontXL
        : (isSmallScreen ? AppSizes.fontM : AppSizes.fontL);
    final descSize = isDesktop
        ? AppSizes.fontS
        : (isSmallScreen ? AppSizes.fontXXS : AppSizes.fontXS);

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: AppSizes.elevationM,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              imageUrl: category.imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              fallbackIcon: _getIconData(category.icon),
              fallbackIconSize: 48,
              fallbackIconColor: Colors.white,
              fallbackBackgroundColor: color,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Positioned(
              top: AppSizes.paddingM,
              right: AppSizes.paddingM,
              child: _buildStatusBadge(),
            ),
            Positioned(
              top: AppSizes.paddingM,
              left: AppSizes.paddingM,
              child: _buildIconOverlay(color, iconSize),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomContent(
                titleSize,
                descSize,
                isDesktop,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: AppSizes.paddingXS,
      ),
      decoration: BoxDecoration(
        color: category.isActive ? AppColors.success : AppColors.error,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: AppSizes.elevationS,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category.isActive
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: Colors.white,
            size: AppSizes.iconXS,
          ),
          const SizedBox(width: 4),
          Text(
            category.isActive ? 'Ativo' : 'Inativo',
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppSizes.fontXXS,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconOverlay(Color color, double iconSize) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingS),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: AppSizes.elevationS,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getIconData(category.icon),
        color: color,
        size: iconSize * 0.5,
      ),
    );
  }

  Widget _buildBottomContent(
    double titleSize,
    double descSize,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.9),
          ],
          stops: const [0.0, 0.8],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppSizes.paddingXS),
          Text(
            category.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: descSize,
              height: 1.3,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppSizes.paddingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    color: Colors.white,
                    backgroundColor: AppColors.primary,
                    onPressed: onEdit,
                    tooltip: 'Editar categoria',
                  ),
                  SizedBox(width: AppSizes.paddingXS),
                  _buildActionButton(
                    icon: Icons.delete_rounded,
                    color: Colors.white,
                    backgroundColor: AppColors.error,
                    onPressed: onDelete,
                    tooltip: 'Excluir categoria',
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Transform.scale(
                  scale: isDesktop ? 1.0 : 0.8,
                  child: Switch(
                    value: category.isActive,
                    onChanged: (_) => onToggleActive(),
                    activeThumbColor: AppColors.success,
                    activeTrackColor: AppColors.success.withOpacity(0.5),
                    inactiveThumbColor: Colors.grey.shade300,
                    inactiveTrackColor: Colors.grey.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Container(
            padding: EdgeInsets.all(AppSizes.paddingS),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: AppSizes.elevationS,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: AppSizes.iconS,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    if (category.color != null && category.color!.isNotEmpty) {
      try {
        String colorStr = category.color!.replaceFirst('#', '');
        if (colorStr.length == 6) {
          return Color(int.parse('FF$colorStr', radix: 16));
        } else if (colorStr.length == 8) {
          return Color(int.parse(colorStr, radix: 16));
        }
      } catch (e) {
        debugPrint('Erro ao parsear cor: $e');
      }
    }
    return AppColors.primary;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'plumbing':
        return Icons.plumbing;
      case 'format_paint':
        return Icons.format_paint;
      case 'eco':
        return Icons.eco;
      case 'construction':
        return Icons.construction;
      case 'handyman':
        return Icons.handyman;
      case 'pets':
        return Icons.pets;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'school':
        return Icons.school;
      case 'medical_services':
        return Icons.medical_services;
      case 'celebration':
        return Icons.celebration;
      case 'electrical_services':
        return Icons.electrical_services;
      default:
        return Icons.category_rounded;
    }
  }
}
