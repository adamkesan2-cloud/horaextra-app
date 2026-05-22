// lib/presentation/features/dashboard/admin/widgets/stat_card.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_sizes.dart';
import 'package:horaextra_app/core/widgets/shared/custom_card.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDesktop;
  final double?
      progressValue; // Opcional: valor da barra de progresso (0.0 a 1.0)
  final VoidCallback? onTap; // Opcional: ação ao clicar no card

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isDesktop = false,
    this.progressValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;
    final isSmallScreen = screenWidth < 600;

    // Tamanhos responsivos baseados nas constantes do AppSizes
    final iconSize = isDesktop
        ? AppSizes.iconXL
        : (isLargeScreen ? AppSizes.iconL : AppSizes.iconM);

    final valueSize = isDesktop
        ? AppSizes.fontXXXL
        : (isLargeScreen ? AppSizes.fontXXL : AppSizes.fontXL);

    final titleSize = isDesktop
        ? AppSizes.fontM
        : (isLargeScreen ? AppSizes.fontS : AppSizes.fontXS);

    final padding = isDesktop
        ? AppSizes.paddingL
        : (isLargeScreen ? AppSizes.paddingM : AppSizes.paddingM);

    final borderRadius = isSmallScreen ? AppSizes.radiusM : AppSizes.radiusL;

    return CustomCard(
      padding: EdgeInsets.all(padding),
      withShadow: true,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Layout diferente para telas muito pequenas
          if (constraints.maxWidth < 200) {
            return _buildCompactLayout(
                theme, iconSize, valueSize, titleSize, padding);
          }
          return _buildNormalLayout(
              theme, iconSize, valueSize, titleSize, padding);
        },
      ),
    );
  }

  // Layout normal para a maioria das telas
  Widget _buildNormalLayout(
    ThemeData theme,
    double iconSize,
    double valueSize,
    double titleSize,
    double padding,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linha superior com ícone e valor
        Row(
          children: [
            // Ícone com fundo gradiente
            _buildIconWithBackground(padding, iconSize),
            const Spacer(),
            // Valor com efeito de destaque
            _buildValueWithGradient(valueSize),
          ],
        ),

        const SizedBox(height: AppSizes.paddingM),

        // Título
        Text(
          title,
          style: TextStyle(
            fontSize: titleSize,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),

        // Barra de progresso (se fornecida)
        if (progressValue != null) ...[
          const SizedBox(height: AppSizes.paddingS),
          _buildProgressBar(),
        ],
      ],
    );
  }

  // Layout compacto para telas muito pequenas
  Widget _buildCompactLayout(
    ThemeData theme,
    double iconSize,
    double valueSize,
    double titleSize,
    double padding,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ícone
        _buildIconWithBackground(padding * 0.8, iconSize * 0.9),

        const SizedBox(height: AppSizes.paddingS),

        // Valor
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize * 0.9,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: AppSizes.paddingXS),

        // Título
        Text(
          title,
          style: TextStyle(
            fontSize: titleSize,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // Barra de progresso (se fornecida)
        if (progressValue != null) ...[
          const SizedBox(height: AppSizes.paddingXS),
          _buildProgressBar(),
        ],
      ],
    );
  }

  // Widget do ícone com fundo
  Widget _buildIconWithBackground(double padding, double iconSize) {
    return Container(
      padding: EdgeInsets.all(padding * 0.4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: iconSize,
      ),
    );
  }

  // Widget do valor com efeito gradiente
  Widget _buildValueWithGradient(double valueSize) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [color, color.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        value,
        style: TextStyle(
          fontSize: valueSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // Barra de progresso
  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXS),
      child: LinearProgressIndicator(
        value: progressValue?.clamp(0.0, 1.0) ?? 0.0,
        backgroundColor: color.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: AppSizes.paddingXS,
      ),
    );
  }
}
