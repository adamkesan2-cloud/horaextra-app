class Environment {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool isDevelopment = !isProduction;
  static String get apiBaseUrl {
    return 'https://horaextra-backend.vercel.app/api';
  }
}