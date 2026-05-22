// lib/core/widgets/base_card.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_sizes.dart';

class BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const BaseCard({
    super.key,
    required this.child,
    this.onTap,
    this.height,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Container(
            padding: padding ?? EdgeInsets.all(AppSizes.paddingM),
            child: child,
          ),
        ),
      ),
    );
  }
}
