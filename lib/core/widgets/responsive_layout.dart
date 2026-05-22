// lib/core/widgets/responsive_layout.dart
import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  // Breakpoints otimizados
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < mobileBreakpoint) {
          return mobile;
        } else if (constraints.maxWidth < tabletBreakpoint) {
          return tablet ?? mobile;
        } else {
          return desktop;
        }
      },
    );
  }

  // Métodos estáticos para compatibilidade
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
}

// Extension para facilitar o uso em qualquer lugar
extension ResponsiveExtension on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(this).size.width >= 600 &&
      MediaQuery.of(this).size.width < 1024;
  bool get isDesktop => MediaQuery.of(this).size.width >= 1024;

  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;

  // Valores responsivos
  T responsive<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop) return desktop;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }

  // Padding responsivo
  EdgeInsets get responsivePadding {
    if (isDesktop) return const EdgeInsets.all(32);
    if (isTablet) return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }
}
