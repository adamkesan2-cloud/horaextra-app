import 'package:flutter/material.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/providers/category_provider.dart';
import 'package:horaextra_app/core/providers/service_provider.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const HoraExtraApp());
}

class HoraExtraApp extends StatelessWidget {
  const HoraExtraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthProvider primeiro
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // ApiService como Provider simples
        Provider<ApiService>(
          create: (context) {
            final authProvider = context.read<AuthProvider>();
            return ApiService(authProvider);
          },
        ),

        // AppProvider como ChangeNotifierProxyProvider
        ChangeNotifierProxyProvider<ApiService, AppProvider>(
          create: (context) => AppProvider(context.read<ApiService>()),
          update: (context, apiService, previous) {
            return previous ?? AppProvider(apiService);
          },
        ),

        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'HoraExtra',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.black87),
                titleTextStyle: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            initialRoute: AppRoutes.login,
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}
