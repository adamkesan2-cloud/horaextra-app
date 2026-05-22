// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Cores principais da marca
  static const Color primaryBlue = Color(0xFF1E3A5F); // Azul escuro
  static const Color primaryCream = Color(0xFFFFFFFF); // Branco

  // Variações do azul
  static const Color blueDark = Color(0xFF0A1A2F);
  static const Color blueMedium = Color(0xFF2C4A6E);
  static const Color blueLight = Color(0xFF3A5A7E);
  static const Color blueVeryLight = Color(0xFFE8F0F8);

  // Variações do branco/cinza
  static const Color creamDark = Color(0xFFE5E5E5);
  static const Color creamMedium = Color(0xFFF5F5F5);
  static const Color creamLight = Color(0xFFFAFAFA);

  // Escala de cinza
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  static const Color black = Color(0xFF000000);

  // Cores funcionais
  static const Color primary = primaryBlue;
  static const Color secondary = Color(0xFFF5F5F5);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = blueMedium;

  // Cores específicas para perfis
  static const Color providerPrimary = blueMedium;
  static const Color clientPrimary = primaryBlue;

  // Fundo e superfície
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = white;
  static const Color textPrimary = blueDark;
  static const Color textSecondary = blueMedium;
  static const Color textHint = blueLight;
  static const Color border = Color(0xFFE5E5E5);

  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, blueMedium],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient providerGradient = LinearGradient(
    colors: [blueMedium, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient clientGradient = LinearGradient(
    colors: [primaryBlue, blueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient creamGradient = LinearGradient(
    colors: [Color(0xFFF5F5F5), Color(0xFFFAFAFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Cores para cards e elementos
  static const Color cardBackground = white;
  static const Color cardBorder = Color(0xFFE5E5E5);
  static const Color shadow = Color(0x1A000000);
}
