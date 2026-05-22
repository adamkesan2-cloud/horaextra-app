// lib/core/widgets/shared/custom_card.dart
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final Color? backgroundColor;
  final bool withShadow;
  final double? elevation;

  const CustomCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.withShadow = false,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Converte BorderRadiusGeometry para BorderRadius se necessário
    final BorderRadius? resolvedBorderRadius;
    if (borderRadius == null) {
      resolvedBorderRadius = BorderRadius.circular(16);
    } else if (borderRadius is BorderRadius) {
      resolvedBorderRadius = borderRadius as BorderRadius?;
    } else {
      // Tenta criar um BorderRadius a partir do BorderRadiusGeometry
      resolvedBorderRadius = BorderRadius.only(
        topLeft: borderRadius!.resolve(Directionality.of(context)).topLeft,
        topRight: borderRadius!.resolve(Directionality.of(context)).topRight,
        bottomLeft:
            borderRadius!.resolve(Directionality.of(context)).bottomLeft,
        bottomRight:
            borderRadius!.resolve(Directionality.of(context)).bottomRight,
      );
    }

    BoxDecoration decoration = BoxDecoration(
      color: backgroundColor ?? theme.cardColor,
      borderRadius: resolvedBorderRadius,
    );

    if (withShadow) {
      decoration = decoration.copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    final card = Container(
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: resolvedBorderRadius,
          child: card,
        ),
      );
    }

    return card;
  }
}
