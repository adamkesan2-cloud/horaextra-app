// lib/presentation/features/dashboard/client/client_home_screen.dart
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/data/models/category/category_model.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/data/models/user/user_model.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import 'package:provider/provider.dart';
import 'category_services_screen.dart';
import 'widgets/service_card.dart';
import 'dart:convert'; // para base64Decode

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ServiceModel> _searchResults = [];

  // Posição do botão mapa draggável
  Offset _mapBtnPos = const Offset(double.infinity, double.infinity);
  bool _mapBtnPosInitialized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() =>
      setState(() => _searchQuery = _searchController.text);

  void _performSearch() {
    if (_searchQuery.isEmpty) return;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _searchResults = appProvider.searchServices(_searchQuery));
    _showSearchResults(context);
  }

  void _showSearchResults(BuildContext context) {
    if (_searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nenhum serviço encontrado'),
          backgroundColor: AppColors.blueMedium,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Resultados para "$_searchQuery"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primaryBlue),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ServiceCard(
                    service: _searchResults[index],
                    isDesktop: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 600 && size.width <= 1024;
    final provider = Provider.of<AppProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final activeCategories = provider.getActiveCategories();

    // Inicializa posição: canto inferior direito acima do safe area
    if (!_mapBtnPosInitialized && size.width > 0) {
      _mapBtnPos = Offset(size.width - 96, size.height - 160);
      _mapBtnPosInitialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Conteúdo scrollável ──────────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child:
                      _buildHeader(isDesktop, isTablet, provider, authProvider),
                ),
                SliverToBoxAdapter(
                  child: _buildCategoriesSection(
                      isDesktop, isTablet, activeCategories),
                ),
                SliverToBoxAdapter(
                  child: _buildFooterSection(isDesktop, isTablet),
                ),
                // Espaço para o botão não cobrir conteúdo
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),

          // ── Botão mapa draggável ─────────────────────────────────────────
          if (_mapBtnPosInitialized)
            Positioned(
              left: _mapBtnPos.dx,
              top: _mapBtnPos.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    double nx = _mapBtnPos.dx + details.delta.dx;
                    double ny = _mapBtnPos.dy + details.delta.dy;
                    nx = nx.clamp(0.0, size.width - 80);
                    ny = ny.clamp(0.0, size.height - 80);
                    _mapBtnPos = Offset(nx, ny);
                  });
                },
                onTap: () => Navigator.pushNamed(context, AppRoutes.clientMap),
                child: const _MapFAB(),
              ),
            ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    bool isDesktop,
    bool isTablet,
    AppProvider provider,
    AuthProvider authProvider,
  ) {
    final user = authProvider.currentUser;
    final notificationsCount = 0;
    final avatarVersion = authProvider.avatarVersion;

    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 16,
        isDesktop ? 20 : 12,
        isDesktop ? 24 : 16,
        isDesktop ? 20 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar | Busca | Notificação
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ Avatar → perfil (com versão para forçar recarregamento)
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.clientProfile),
                child: Container(
                  width: isDesktop ? 48 : 40,
                  height: isDesktop ? 48 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    border: Border.all(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _buildAvatar(user, isDesktop, avatarVersion),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Barra de busca
              Expanded(
                child: Container(
                  height: isDesktop ? 48 : 42,
                  decoration: BoxDecoration(
                    color: AppColors.creamLight,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _performSearch(),
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: isDesktop ? 15 : 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar serviços...',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontSize: isDesktop ? 15 : 13,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                              size: isDesktop ? 22 : 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _searchResults = [];
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.clear_rounded,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _performSearch,
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Notificações
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.clientNotifications,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: isDesktop ? 48 : 40,
                      height: isDesktop ? 48 : 40,
                      decoration: BoxDecoration(
                        color: AppColors.creamMedium,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: AppColors.primaryBlue,
                        size: isDesktop ? 26 : 22,
                      ),
                    ),
                    if (notificationsCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$notificationsCount',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Saudação
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Olá, ${user?.name.split(' ').first ?? 'Cliente'}! 👋',
              style: TextStyle(
                fontSize: isDesktop ? 15 : 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Método para construir o avatar
  Widget _buildAvatar(UserModel? user, bool isDesktop, int avatarVersion) {
    final photoUrl = user?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    if (!hasPhoto) {
      return Center(
        child: Text(
          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'C',
          style: TextStyle(
            fontSize: isDesktop ? 20 : 17,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      );
    }

    // ✅ Base64 — usar Image.memory
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Str = photoUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Center(
          child: Text(
            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'C',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 17,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        );
      }
    }

    // ✅ URL normal — usar Image.network
    final fullUrl = ApiConfig.getAvatarUrl(photoUrl, timestamp: avatarVersion);
    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      key: ValueKey('avatar_$avatarVersion'),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: AppColors.white,
            strokeWidth: 2,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Text(
            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'C',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 17,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        );
      },
    );
  }

  // ── CATEGORIAS ─────────────────────────────────────────────────────────────
  Widget _buildCategoriesSection(
    bool isDesktop,
    bool isTablet,
    List<CategoryModel> categories,
  ) {
    if (categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.category_outlined,
                size: isDesktop ? 80 : 64,
                color: AppColors.grey400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma categoria disponível',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Em breve novos serviços estarão disponíveis',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: isDesktop ? 14 : 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double cardHeight = isDesktop ? 220.0 : (isTablet ? 220.0 : 200.0);
    final double spacing = isDesktop ? 20.0 : 16.0;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categorias',
                style: TextStyle(
                  fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.creamMedium,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${categories.length} disponíveis',
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isDesktop)
            _buildDesktopGrid(categories, cardHeight, spacing)
          else if (isTablet)
            _buildTabletGrid(categories, cardHeight, spacing)
          else
            _buildMobileList(categories, cardHeight, spacing),
        ],
      ),
    );
  }

  Widget _buildDesktopGrid(
    List<CategoryModel> categories,
    double cardHeight,
    double spacing,
  ) {
    return Column(
      children: [
        for (int i = 0; i < categories.length; i += 3)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 3 < categories.length ? spacing : 0,
            ),
            child: Row(
              children: [
                for (int j = i; j < (i + 3).clamp(0, categories.length); j++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: j > i ? spacing : 0),
                      child: SizedBox(
                        height: cardHeight,
                        child: _buildCategoryCard(categories[j], true,
                            isTablet: false),
                      ),
                    ),
                  ),
                if ((categories.length - i) == 1) ...[
                  SizedBox(width: spacing),
                  const Expanded(child: SizedBox()),
                  SizedBox(width: spacing),
                  const Expanded(child: SizedBox()),
                ],
                if ((categories.length - i) == 2) ...[
                  SizedBox(width: spacing),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTabletGrid(
    List<CategoryModel> categories,
    double cardHeight,
    double spacing,
  ) {
    return Column(
      children: [
        for (int i = 0; i < categories.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < categories.length ? spacing : 0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: cardHeight,
                    child: _buildCategoryCard(categories[i], false,
                        isTablet: true),
                  ),
                ),
                if (i + 1 < categories.length) ...[
                  SizedBox(width: spacing),
                  Expanded(
                    child: SizedBox(
                      height: cardHeight,
                      child: _buildCategoryCard(categories[i + 1], false,
                          isTablet: true),
                    ),
                  ),
                ] else ...[
                  SizedBox(width: spacing),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMobileList(
    List<CategoryModel> categories,
    double cardHeight,
    double spacing,
  ) {
    return Column(
      children: [
        for (int i = 0; i < categories.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < categories.length - 1 ? spacing : 0,
            ),
            child: SizedBox(
              height: cardHeight,
              child: _buildCategoryCard(categories[i], false, isTablet: false),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryCard(
    CategoryModel category,
    bool isDesktop, {
    bool isTablet = false,
  }) {
    final color = _getCategoryColor(category);
    final imageUrl = ApiConfig.getFullImageUrl(category.imageUrl);
    final servicesCount = _getServicesCount(category);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryServicesScreen(category: category),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildFallbackBackground(color),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _buildFallbackBackground(color);
                      },
                    )
                  : _buildFallbackBackground(color),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(category.icon),
                    color: color,
                    size: isDesktop ? 20 : 18,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 4),
                      Text(
                        category.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isDesktop ? 11 : 10,
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
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '$servicesCount serviços',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackBackground(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.8), color],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.category_rounded,
          size: 40,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

  int _getServicesCount(CategoryModel category) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return provider.getServicesByCategory(category.id).length;
  }

  Widget _buildFooterSection(bool isDesktop, bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isDesktop ? 24 : 16),
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.access_time_filled,
            size: isDesktop ? 48 : 40,
            color: AppColors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'HoraExtra',
            style: TextStyle(
              fontSize: isDesktop ? 28 : 24,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Soluções rápidas e confiáveis para o seu dia a dia',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              color: AppColors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFooterIcon(
                Icons.verified_rounded,
                'Profissionais\nQualificados',
              ),
              const SizedBox(width: 32),
              _buildFooterIcon(
                Icons.schedule_rounded,
                'Atendimento\nRápido',
              ),
              const SizedBox(width: 32),
              _buildFooterIcon(
                Icons.security_rounded,
                'Serviço\nSeguro',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            '© 2024 HoraExtra - Todos os direitos reservados',
            style: TextStyle(
              fontSize: isDesktop ? 12 : 10,
              color: AppColors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(CategoryModel category) {
    if (category.color != null && category.color!.isNotEmpty) {
      try {
        String colorStr = category.color!.replaceFirst('#', '');
        if (colorStr.length == 6) {
          return Color(int.parse('FF$colorStr', radix: 16));
        } else if (colorStr.length == 8) {
          return Color(int.parse(colorStr, radix: 16));
        }
      } catch (_) {}
    }
    return AppColors.primaryBlue;
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'cleaning_services':
        return Icons.cleaning_services_rounded;
      case 'electric_bolt':
        return Icons.electric_bolt_rounded;
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'format_paint':
        return Icons.format_paint_rounded;
      case 'eco':
        return Icons.eco_rounded;
      case 'construction':
        return Icons.construction_rounded;
      case 'handyman':
        return Icons.handyman_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'celebration':
        return Icons.celebration_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão FAB de mapa redondo — cores de mapa real, draggável
// ─────────────────────────────────────────────────────────────────────────────
class _MapFAB extends StatelessWidget {
  const _MapFAB();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Encontrar Prestadores no Mapa',
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.32),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fundo: mapa desenhado com CustomPainter
              CustomPaint(painter: _MapCirclePainter()),

              // Ícone de localização + label
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFE53935),
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Mapa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              // Borda branca externa
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinta um mini-mapa realista dentro de um círculo
class _MapCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Clip para o círculo
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // ── 1. Fundo verde-claro (vegetação/terra) ────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFECF3E8),
    );

    // ── 2. Quarteirões (bege) ─────────────────────────────────────────────
    final blockPaint = Paint()..color = const Color(0xFFD5C99E);
    for (final b in [
      Rect.fromLTWH(4, 5, 24, 17),
      Rect.fromLTWH(32, 3, 20, 22),
      Rect.fromLTWH(55, 7, 17, 15),
      Rect.fromLTWH(5, 44, 22, 19),
      Rect.fromLTWH(32, 48, 22, 18),
      Rect.fromLTWH(56, 44, 16, 21),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, const Radius.circular(2.5)),
        blockPaint,
      );
    }

    // ── 3. Parque (verde escuro) ───────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(9, 26, 18, 14),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF7CB87C).withOpacity(0.8),
    );
    // Textura do parque (linhas finas)
    final parkLine = Paint()
      ..color = const Color(0xFF5A9E5A).withOpacity(0.5)
      ..strokeWidth = 1;
    for (double x = 11; x < 26; x += 4) {
      canvas.drawLine(Offset(x, 27), Offset(x, 39), parkLine);
    }

    // ── 4. Rio (azul ondulado) ─────────────────────────────────────────────
    final riverPaint = Paint()
      ..color = const Color(0xFF5BA4CF).withOpacity(0.85)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(size.width * 0.80, 0)
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.3,
        size.width * 0.75,
        size.height * 0.6,
        size.width * 0.88,
        size.height,
      );
    canvas.drawPath(riverPath, riverPaint);

    // Reflexo do rio
    canvas.drawPath(
      riverPath,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── 5. Ruas principais (brancas) ──────────────────────────────────────
    final roadMain = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.butt;
    // Horizontal
    canvas.drawLine(Offset(0, cy), Offset(size.width * 0.76, cy), roadMain);
    // Vertical
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), roadMain);

    // Linhas centrais amarelas das ruas
    final roadCenter = Paint()
      ..color = const Color(0xFFFFD54F).withOpacity(0.7)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width * 0.76, cy),
      roadCenter,
    );
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), roadCenter);

    // ── 6. Ruas secundárias ───────────────────────────────────────────────
    final roadSec = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.5;
    for (final pts in [
      [Offset(0.0, 27.0), Offset(size.width * 0.76, 27.0)],
      [Offset(0.0, 47.0), Offset(size.width * 0.76, 47.0)],
      [Offset(30.0, 0.0), Offset(30.0, size.height)],
      [Offset(52.0, 0.0), Offset(52.0, size.height)],
    ]) {
      canvas.drawLine(pts[0], pts[1], roadSec);
    }

    // ── 7. Vinheta escura nas bordas ──────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.38),
          ],
          stops: const [0.55, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
