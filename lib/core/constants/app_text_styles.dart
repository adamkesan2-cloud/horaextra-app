// lib/core/constants/app_text_styles.dart
import 'package:flutter/material.dart';

class AppTextStyles {
  // Títulos de Seção
  static TextStyle sectionTitle(BuildContext context) {
    return const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );
  }

  // Títulos de Card
  static TextStyle cardTitle(BuildContext context) {
    return const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
  }

  // Subtítulos de Card
  static TextStyle cardSubtitle(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      color: Theme.of(context).disabledColor,
    );
  }

  // Headline Grande
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  // Headline Médio
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  // Headline Pequeno
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  // Título Grande
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  // Título Médio
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // Título Pequeno
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Body Large
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  // Body Medium
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // Body Small
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  // Label Large
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  // Label Medium
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // Label Small
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  // Button Text
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // Caption
  static TextStyle caption(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      color: Theme.of(context).disabledColor,
    );
  }

  // Overline
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
  );
}
