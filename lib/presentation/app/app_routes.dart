// lib/presentation/app/app_routes.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/presentation/features/auth/login/view/login_screen.dart';
import 'package:horaextra_app/presentation/features/auth/role_selection/role_selection_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/client/client_dashboard.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_dashboard.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_dashboard.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_services_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/admin/admin_categories_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_services_screen.dart';
import 'package:horaextra_app/presentation/features/profile/view/edit_profile_screen.dart';
import 'package:horaextra_app/presentation/features/profile/view/client_profile_screen.dart';
import 'package:horaextra_app/presentation/features/profile/view/provider_own_profile_screen.dart';
import 'package:horaextra_app/presentation/features/profile/view/provider_profile_screen.dart';
import 'package:horaextra_app/presentation/features/map/client_map_screen.dart';
import 'package:horaextra_app/presentation/features/map/provider_map_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/client/client_requests_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_requests_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/provider/provider_history_screen.dart';
import 'package:horaextra_app/presentation/features/requests/select_provider_screen.dart';
import 'package:horaextra_app/presentation/features/notifications/request_notifications_screen.dart';
import 'package:horaextra_app/presentation/features/notifications/provider_notifications_screen.dart';
import 'package:horaextra_app/presentation/features/dashboard/client/category_services_screen.dart';
import 'package:horaextra_app/presentation/features/requests/request_tracking_screen.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/data/models/provider/provider_selection_model.dart';

class AppRoutes {
  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String roleSelection = '/role-selection';

  // ── Dashboards ────────────────────────────────────────────────────────────
  static const String clientDashboard = '/client-dashboard';
  static const String providerDashboard = '/provider-dashboard';
  static const String adminDashboard = '/admin-dashboard';

  // ── Mapa ──────────────────────────────────────────────────────────────────
  static const String clientMap = '/client-map';
  static const String providerMap = '/provider-map';

  // ── Cliente ───────────────────────────────────────────────────────────────
  static const String clientProfile = '/client-profile';
  static const String clientRequests = '/client-requests';
  static const String clientFavorites = '/client-favorites';
  static const String clientAddresses = '/client-addresses';
  static const String clientPayments = '/client-payments';
  static const String clientNotifications = '/client-notifications';
  static const String clientServices = '/client-services';
  static const String categoryServices = '/category-services';

  // ── Prestador ─────────────────────────────────────────────────────────────
  static const String providerOwnProfile = '/provider-own-profile';
  static const String providerProfile = '/provider-profile';
  static const String providerServices = '/provider-services';
  static const String providerRequests = '/provider-requests';
  static const String providerHistory = '/provider-history';
  static const String providerNotifications = '/provider-notifications';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const String adminUsers = '/admin-users';
  static const String adminCategories = '/admin-categories';
  static const String adminServices = '/admin-services';
  static const String adminReports = '/admin-reports';

  // ── Solicitações ──────────────────────────────────────────────────────────
  static const String selectProvider = '/select-provider';
  static const String requestNotifications = '/request-notifications';
  static const String requestTracking = '/request-tracking';

  // ── Comuns ────────────────────────────────────────────────────────────────
  static const String settings = '/settings';
  static const String editProfile = '/edit-profile';
  static const String requestDetail = '/request-detail';
  static const String serviceDetail = '/service-detail';
  static const String privacy = '/privacy';
  static const String terms = '/terms';
  static const String help = '/help';

  // ── Gerador de rotas ──────────────────────────────────────────────────────
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      // ── AUTH ──────────────────────────────────────────────────────────────
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: routeSettings,
        );

      case roleSelection:
        return MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
          settings: routeSettings,
        );

      // ── DASHBOARDS ────────────────────────────────────────────────────────
      case clientDashboard:
        return MaterialPageRoute(
          builder: (_) => const ClientDashboard(),
          settings: routeSettings,
          maintainState: true,
        );

      case providerDashboard:
        return MaterialPageRoute(
          builder: (_) => const ProviderDashboard(),
          settings: routeSettings,
          maintainState: true,
        );

      case adminDashboard:
        return MaterialPageRoute(
          builder: (_) => const AdminDashboard(),
          settings: routeSettings,
          maintainState: true,
        );

      // ── MAPA ──────────────────────────────────────────────────────────────
      case clientMap:
        final args = routeSettings.arguments;
        if (args is Map<String, dynamic> && args.containsKey('requestId')) {
          return MaterialPageRoute(
            builder: (_) => ClientMapScreen(
              requestId: args['requestId'],
              providerId: args['providerId'],
              providerName: args['providerName'],
            ),
            settings: routeSettings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const ClientMapScreen(),
          settings: routeSettings,
        );

      case providerMap:
        final args = routeSettings.arguments;
        if (args is Map<String, dynamic> && args.containsKey('requestId')) {
          return MaterialPageRoute(
            builder: (_) => ProviderMapScreen(requestId: args['requestId']),
            settings: routeSettings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const ProviderMapScreen(),
          settings: routeSettings,
        );

      // ── PERFIL ────────────────────────────────────────────────────────────
      case editProfile:
        return MaterialPageRoute(
          builder: (_) => const EditProfileScreen(),
          settings: routeSettings,
        );

      case clientProfile:
        return MaterialPageRoute(
          builder: (_) => const ClientProfileScreen(),
          settings: routeSettings,
        );

      case providerOwnProfile:
        return MaterialPageRoute(
          builder: (_) => const ProviderOwnProfileScreen(),
          settings: routeSettings,
        );

      case providerProfile:
        final args = routeSettings.arguments;
        if (args is Map<String, dynamic> && args.containsKey('providerId')) {
          return MaterialPageRoute(
            builder: (_) =>
                ProviderProfileScreen(providerId: args['providerId']),
            settings: routeSettings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const ProviderProfileScreen(),
          settings: routeSettings,
        );

      // ── ADMIN ─────────────────────────────────────────────────────────────
      case adminServices:
        return MaterialPageRoute(
          builder: (_) => const AdminServicesScreen(),
          settings: routeSettings,
        );

      case adminCategories:
        return MaterialPageRoute(
          builder: (_) => const AdminCategoriesScreen(),
          settings: routeSettings,
        );

      // ── CLIENTE ───────────────────────────────────────────────────────────
      case clientRequests:
        return MaterialPageRoute(
          builder: (_) => const ClientRequestsScreen(),
          settings: routeSettings,
        );

      case categoryServices:
        final category = routeSettings.arguments;
        if (category is CategoryModel) {
          return MaterialPageRoute(
            builder: (_) => CategoryServicesScreen(category: category),
            settings: routeSettings,
          );
        }
        return _errorRoute('Categoria não especificada');

      // ── PRESTADOR ─────────────────────────────────────────────────────────
      case providerRequests:
        return MaterialPageRoute(
          builder: (_) => const ProviderRequestsScreen(),
          settings: routeSettings,
        );

      case providerHistory:
        return MaterialPageRoute(
          builder: (_) => const ProviderHistoryScreen(),
          settings: routeSettings,
        );

      case providerNotifications:
        return MaterialPageRoute(
          builder: (_) => const ProviderNotificationsScreen(),
          settings: routeSettings,
        );

      case providerServices:
        return MaterialPageRoute(
          builder: (_) => const ProviderServicesScreen(),
          settings: routeSettings,
        );

      // ── SOLICITAÇÕES ──────────────────────────────────────────────────────
      case selectProvider:
        final args = routeSettings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => SelectProviderScreen(
              service: args['service'] as ServiceModel,
              scheduledDate: args['scheduledDate'] as DateTime?,
              observations: args['observations'] as String?,
              isUrgent: args['isUrgent'] as bool? ?? false,
              quantity: args['quantity'] as int? ?? 1, // ✅ Adicionado quantity
            ),
            settings: routeSettings,
          );
        }
        return _errorRoute('Dados do serviço não fornecidos');

      case requestNotifications:
        return MaterialPageRoute(
          builder: (_) => const RequestNotificationsScreen(),
          settings: routeSettings,
        );

      case requestTracking:
        final args = routeSettings.arguments;
        if (args is Map<String, dynamic>) {
          // Converter a lista corretamente
          List<ProviderSelectionModel> providers = [];
          if (args['selectedProviders'] != null) {
            final list = args['selectedProviders'] as List;
            providers = list.map((item) {
              if (item is ProviderSelectionModel) return item;
              if (item is Map<String, dynamic>) {
                return ProviderSelectionModel.fromJson(item);
              }
              return item as ProviderSelectionModel;
            }).toList();
          }

          return MaterialPageRoute(
            builder: (_) => RequestTrackingScreen(
              serviceName: args['serviceName'] as String? ?? 'Serviço',
              selectedProviders: providers,
              isUrgent: args['isUrgent'] as bool? ?? false,
              scheduledDate: args['scheduledDate'] as DateTime?,
              requestId: args['requestId'] as String?,
            ),
            settings: routeSettings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const RequestTrackingScreen(
            serviceName: 'Serviço',
            selectedProviders: [],
          ),
          settings: routeSettings,
        );

      // ── EM CONSTRUÇÃO ─────────────────────────────────────────────────────
      case register:
      case forgotPassword:
      case clientFavorites:
      case clientAddresses:
      case clientPayments:
      case clientNotifications:
      case clientServices:
      case adminUsers:
      case adminReports:
      case settings:
      case privacy:
      case terms:
      case help:
      case requestDetail:
      case serviceDetail:
        return _underConstructionRoute(routeSettings);

      // ── DEFAULT ───────────────────────────────────────────────────────────
      default:
        return _errorRoute('Rota não encontrada: ${routeSettings.name}');
    }
  }

  static Route<dynamic> _underConstructionRoute(RouteSettings routeSettings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(_getRouteName(routeSettings.name ?? '')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              Text('Em Construção',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_getRouteName(routeSettings.name ?? ''),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
      settings: routeSettings,
    );
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                  }
                },
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _getRouteName(String route) {
    final names = {
      login: 'Login',
      register: 'Registo',
      forgotPassword: 'Recuperar Password',
      roleSelection: 'Selecionar Tipo de Conta',
      clientDashboard: 'Dashboard',
      providerDashboard: 'Dashboard',
      adminDashboard: 'Dashboard',
      clientProfile: 'Meu Perfil',
      clientRequests: 'Meus Pedidos',
      clientFavorites: 'Favoritos',
      clientAddresses: 'Endereços',
      clientPayments: 'Pagamentos',
      clientNotifications: 'Notificações',
      clientMap: 'Acompanhar Prestador',
      clientServices: 'Serviços',
      categoryServices: 'Serviços da Categoria',
      providerOwnProfile: 'Meu Perfil',
      providerProfile: 'Perfil Público',
      providerServices: 'Meus Serviços',
      providerRequests: 'Pedidos Recebidos',
      providerHistory: 'Histórico',
      providerMap: 'Mapa de Serviços',
      providerNotifications: 'Solicitações',
      adminUsers: 'Usuários',
      adminCategories: 'Categorias',
      adminServices: 'Serviços',
      adminReports: 'Relatórios',
      selectProvider: 'Selecionar Prestador',
      requestNotifications: 'Solicitações',
      editProfile: 'Editar Perfil',
      settings: 'Configurações',
      privacy: 'Política de Privacidade',
      terms: 'Termos de Uso',
      help: 'Ajuda',
      requestDetail: 'Detalhes do Pedido',
      serviceDetail: 'Detalhes do Serviço',
      requestTracking: 'Acompanhar Pedido',
    };
    return names[route] ??
        route.replaceAll('/', '').replaceAll('-', ' ').toUpperCase();
  }
}
