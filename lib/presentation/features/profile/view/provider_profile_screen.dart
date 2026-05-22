// lib/presentation/features/profile/view/provider_profile_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/api_service.dart';
import 'package:horaextra_app/data/models/provider/provider_selection_model.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String? providerId;
  final ProviderSelectionModel? provider;

  const ProviderProfileScreen({
    super.key,
    this.providerId,
    this.provider,
  });

  factory ProviderProfileScreen.fromProvider(ProviderSelectionModel provider) {
    return ProviderProfileScreen(provider: provider);
  }

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoadingProfile = true;
  bool _isLoadingReviews = true;
  bool _isLoadingCanReview = false;
  bool _isSubmittingReview = false;

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _reviews = [];
  int _reviewsTotal = 0;

  // Avaliação
  int _selectedRating = 0;
  final Set<String> _selectedTags = {};
  bool _reviewSubmitted = false;
  bool _canReview = false;
  String? _reviewRequestId;
  String? _canReviewMessage;

  final List<String> _positiveTags = [
    'Excelente profissional',
    'Muito pontual',
    'Preço justo',
    'Educado e profissional',
    'Serviço rápido',
    'Trabalho de qualidade',
    'Muito competente',
    'Recomendo fortemente',
    'Trabalho limpo',
    'Boa comunicação',
  ];

  final List<String> _negativeTags = [
    'Atrasou um pouco',
    'Preço acima do esperado',
    'Precisou voltar para ajustes',
    'Pouca comunicação',
    'Poderia ser mais organizado',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _providerId => widget.provider?.id ?? widget.providerId ?? '';

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadReviews(),
      _loadCanReview(),
    ]);
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.getAuth('/profile/provider/public/$_providerId');
      if (res['success'] == true && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _profile = data;
          _stats = {
            'completedJobs': data['completed_jobs'] ?? 0,
            'rating': data['rating'] ?? 0.0,
            'reviewCount': data['review_count'] ?? 0,
            'responseRate': data['response_rate'] ?? 100,
            'acceptanceRate': data['acceptance_rate'] ?? 100,
          };
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadReviews({int page = 1}) async {
    setState(() => _isLoadingReviews = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api
          .getAuth('/reviews/provider/$_providerId?page=$page&limit=10');
      if (res['success'] == true && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        final list = (data['reviews'] as List? ?? [])
            .map((r) => r as Map<String, dynamic>)
            .toList();
        setState(() {
          _reviews = list;
          _reviewsTotal = data['total'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar avaliações: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _loadCanReview() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isClient) return;

    setState(() => _isLoadingCanReview = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.getAuth('/reviews/can-review/$_providerId');
      if (res['success'] == true && mounted) {
        setState(() {
          _canReview = res['canReview'] == true;
          _reviewRequestId = res['requestId']?.toString();
          _canReviewMessage = res['message']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Erro ao verificar permissão: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCanReview = false);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0 || _selectedTags.isEmpty) return;
    if (_reviewRequestId == null) return;

    setState(() => _isSubmittingReview = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.postAuth('/reviews', {
        'provider_id': _providerId,
        'request_id': _reviewRequestId,
        'rating': _selectedRating,
        'tags': _selectedTags.toList(),
      });
      if (res['success'] == true && mounted) {
        setState(() {
          _reviewSubmitted = true;
          _canReview = false;
        });
        await _loadReviews();
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao enviar avaliação: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Widget _buildAvatarImage(String? photoUrl, double size) {
    final name = _profile['name']?.toString() ?? widget.provider?.name ?? 'P';
    Widget placeholder = Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.white),
      ),
    );

    if (photoUrl == null || photoUrl.isEmpty) return placeholder;

    if (photoUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(photoUrl.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return placeholder;
      }
    }

    final url = photoUrl.startsWith('http')
        ? photoUrl
        : 'https://horaextra-backend-production.up.railway.app$photoUrl';
    return Image.network(url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
              child: CircularProgressIndicator(color: AppColors.white));
        },
        errorBuilder: (_, __, ___) => placeholder);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 768 && size.width <= 1200;
    final isMobile = size.width <= 768;

    final name =
        _profile['name']?.toString() ?? widget.provider?.name ?? 'Prestador';
    final photoUrl =
        _profile['photo_url']?.toString() ?? widget.provider?.photoUrl ?? '';
    final specialties =
        (_profile['specialties'] as List?)?.map((s) => s.toString()).toList() ??
            widget.provider?.specialties ??
            [];
    final isOnline = widget.provider?.isOnline ?? false;
    final location =
        _profile['location_name']?.toString() ?? 'Maputo, Moçambique';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverHeader(name, photoUrl, specialties, isOnline, location,
              isDesktop, isTablet, isMobile),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAboutTab(
                isDesktop, isTablet, isMobile, specialties, location),
            _buildReviewsTab(isDesktop, isTablet, isMobile),
            _buildRateTab(isDesktop, isTablet, isMobile),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDesktop, isMobile),
    );
  }

  // ── SLIVER HEADER ──────────────────────────────────────────────────────────
  SliverAppBar _buildSliverHeader(
    String name,
    String photoUrl,
    List<String> specialties,
    bool isOnline,
    String location,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final expandedHeight = isDesktop ? 360.0 : (isTablet ? 320.0 : 280.0);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.primaryBlue,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.white),
          onPressed: () => _showOptionsMenu(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeaderContent(name, photoUrl, specialties, isOnline,
            location, isDesktop, isTablet, isMobile),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.white,
        indicatorWeight: 3,
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.white.withOpacity(0.6),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: 'Sobre', icon: Icon(Icons.person_outline, size: 18)),
          Tab(text: 'Avaliações', icon: Icon(Icons.star_outline, size: 18)),
          Tab(
              text: 'Avaliar',
              icon: Icon(Icons.rate_review_outlined, size: 18)),
        ],
      ),
    );
  }

  Widget _buildHeaderContent(
    String name,
    String photoUrl,
    List<String> specialties,
    bool isOnline,
    String location,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final rating = (_stats['rating'] ?? widget.provider?.rating ?? 0.0);
    final reviewCount =
        (_stats['reviewCount'] ?? widget.provider?.reviewCount ?? 0);
    final avatarSize = isDesktop ? 110.0 : (isTablet ? 95.0 : 80.0);

    // Ajuste do padding para evitar overflow
    final topPadding = isDesktop ? 100.0 : (isTablet ? 85.0 : 70.0);
    final bottomPadding = isDesktop ? 70.0 : (isTablet ? 60.0 : 50.0);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBlue, Color(0xFF1565C0)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      child: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.white))
          : SingleChildScrollView(
              // ✅ Adicionado SingleChildScrollView para evitar overflow
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildAvatarImage(photoUrl, avatarSize),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nome
                  Text(name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),

                  if (specialties.isNotEmpty)
                    Text(
                      specialties.first,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.white.withOpacity(0.85),
                          fontSize: isDesktop ? 14 : 12),
                    ),
                  const SizedBox(height: 12),

                  // Badges
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _badge(
                          '⭐ ${rating is double ? rating.toStringAsFixed(1) : rating} ($reviewCount)'),
                      _badge('✅ Verificado'),
                      _badge(isOnline ? '🟢 Online' : '⚫ Offline',
                          isOnline ? Colors.green : Colors.grey),
                      _badge('📍 ${_truncateText(location, 20)}'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  Widget _badge(String text, [Color? bgColor]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color:
                bgColor?.withOpacity(0.3) ?? AppColors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      );

  // ── TAB SOBRE ──────────────────────────────────────────────────────────────
  Widget _buildAboutTab(bool isDesktop, bool isTablet, bool isMobile,
      List<String> specialties, String location) {
    if (_isLoadingProfile) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }

    final about = _profile['about']?.toString() ??
        widget.provider?.about ??
        'Profissional qualificado e experiente.';
    final memberSince = _formatDate(_profile['member_since']?.toString());
    final crossCount = isDesktop ? 4 : (isTablet ? 4 : 2);

    final statItems = [
      {
        'icon': Icons.check_circle_rounded,
        'value': '${_stats['completedJobs'] ?? 0}',
        'label': 'Serviços',
        'color': AppColors.success,
      },
      {
        'icon': Icons.star_rounded,
        'value':
            '${(_stats['rating'] ?? 0.0) is double ? (_stats['rating'] as double).toStringAsFixed(1) : _stats['rating'] ?? 0}',
        'label': 'Avaliação',
        'color': AppColors.warning,
      },
      {
        'icon': Icons.speed_rounded,
        'value': '${_stats['responseRate'] ?? 100}%',
        'label': 'Resposta',
        'color': AppColors.info,
      },
      {
        'icon': Icons.thumb_up_rounded,
        'value': '${_stats['acceptanceRate'] ?? 100}%',
        'label': 'Aprovação',
        'color': AppColors.primaryBlue,
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: Column(
        children: [
          // Stats grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 1.2 : 1.5,
            children: statItems
                .map((item) => _statCard(
                    item['icon'] as IconData,
                    item['value'] as String,
                    item['label'] as String,
                    item['color'] as Color,
                    isDesktop))
                .toList(),
          ),
          const SizedBox(height: 20),

          // Sobre
          _card(
            title: 'Sobre',
            icon: Icons.person_outline_rounded,
            isDesktop: isDesktop,
            child: Text(about,
                style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    color: AppColors.blueMedium,
                    height: 1.5)),
          ),
          const SizedBox(height: 16),

          // Especialidades
          if (specialties.isNotEmpty) ...[
            _card(
              title: 'Especialidades',
              icon: Icons.build_circle_outlined,
              isDesktop: isDesktop,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: specialties
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.creamMedium,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.creamDark),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue)),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Informações
          _card(
            title: 'Informações',
            icon: Icons.info_outline_rounded,
            isDesktop: isDesktop,
            child: Column(
              children: [
                _infoRow(
                    Icons.calendar_today_rounded, 'Membro desde', memberSince),
                const SizedBox(height: 12),
                _infoRow(Icons.location_on_rounded, 'Localização', location),
                const SizedBox(height: 12),
                _infoRow(Icons.access_time_rounded, 'Tempo médio de resposta',
                    '< 30 min'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statCard(
      IconData icon, String value, String label, Color color, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isDesktop ? 28 : 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: isDesktop ? 11 : 10, color: AppColors.blueMedium)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: AppColors.creamMedium,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: AppColors.primaryBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.blueLight)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.creamDark),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppColors.creamMedium,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── TAB AVALIAÇÕES ─────────────────────────────────────────────────────────
  Widget _buildReviewsTab(bool isDesktop, bool isTablet, bool isMobile) {
    if (_isLoadingReviews) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border_rounded,
                size: 56, color: AppColors.blueLight),
            const SizedBox(height: 16),
            const Text('Nenhuma avaliação ainda',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue)),
            const SizedBox(height: 6),
            const Text('Este prestador ainda não recebeu avaliações',
                style: TextStyle(fontSize: 12, color: AppColors.blueMedium)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 16 : 20)),
      itemCount: _reviews.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('$_reviewsTotal avaliações',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue)),
          );
        }
        return _reviewCard(_reviews[index - 1], isDesktop);
      },
    );
  }

  Widget _reviewCard(Map<String, dynamic> review, bool isDesktop) {
    final reviewer = review['reviewer'] as Map<String, dynamic>? ?? {};
    final name = reviewer['name']?.toString() ?? 'Cliente';
    final rating = (review['rating'] as num?)?.toInt() ?? 5;
    final tags =
        (review['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
    final createdAt = _formatDate(review['created_at']?.toString());
    final reviewerPhoto = reviewer['photo_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDark),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar do revisor
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.creamMedium),
                child: ClipOval(
                  child: reviewerPhoto != null && reviewerPhoto.isNotEmpty
                      ? _buildAvatarImage(reviewerPhoto, 36)
                      : Center(
                          child: Text(name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isDesktop ? 14 : 13,
                            color: AppColors.primaryBlue)),
                    Text(createdAt,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.blueMedium)),
                  ],
                ),
              ),
              // Estrelas
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.warning,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.4)),
                        ),
                        child: Text(tag,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── TAB AVALIAR ────────────────────────────────────────────────────────────
  Widget _buildRateTab(bool isDesktop, bool isTablet, bool isMobile) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Não é cliente
    if (!authProvider.isClient) {
      return _centeredMessage(
        Icons.info_outline_rounded,
        'Apenas clientes podem avaliar prestadores.',
        AppColors.blueLight,
      );
    }

    // Avaliação enviada com sucesso
    if (_reviewSubmitted) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24 : 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 56),
              ),
              const SizedBox(height: 20),
              const Text('Avaliação enviada!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryBlue)),
              const SizedBox(height: 10),
              const Text(
                'Obrigado pelo feedback!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.blueMedium),
              ),
            ],
          ),
        ),
      );
    }

    // A verificar permissão
    if (_isLoadingCanReview) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }

    // Não pode avaliar
    if (!_canReview) {
      return _centeredMessage(
        Icons.lock_outline_rounded,
        _canReviewMessage ??
            'Você só pode avaliar após um serviço concluído com este prestador.',
        AppColors.blueLight,
      );
    }

    // Formulário de avaliação
    final tags = _selectedRating >= 4 ? _positiveTags : _negativeTags;
    final ratingLabels = [
      '',
      'Muito ruim',
      'Ruim',
      'Regular',
      'Bom',
      'Excelente'
    ];

    final name =
        _profile['name']?.toString() ?? widget.provider?.name ?? 'Prestador';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avaliar ${name.split(' ').first}',
            style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 20),

          // Estrelas
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final selected = i < _selectedRating;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedRating = i + 1;
                    _selectedTags.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.warning,
                      size: selected
                          ? (isMobile ? 40 : 48)
                          : (isMobile ? 32 : 40),
                    ),
                  ),
                );
              }),
            ),
          ),

          if (_selectedRating > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.creamMedium,
                    borderRadius: BorderRadius.circular(16)),
                child: Text(
                  ratingLabels[_selectedRating],
                  style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedRating >= 4
                          ? AppColors.success
                          : AppColors.warning),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              _selectedRating >= 4
                  ? 'O que você mais gostou?'
                  : 'O que poderia melhorar?',
              style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 12),

            // Tags como chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final sel = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag,
                      style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w500,
                          color: sel ? AppColors.white : AppColors.blueMedium)),
                  selected: sel,
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  }),
                  backgroundColor: AppColors.white,
                  selectedColor: AppColors.primaryBlue,
                  checkmarkColor: AppColors.white,
                  side: BorderSide(
                      color: sel ? AppColors.primaryBlue : AppColors.creamDark),
                  shape: StadiumBorder(),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Botão enviar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedRating > 0 &&
                        _selectedTags.isNotEmpty &&
                        !_isSubmittingReview)
                    ? _submitReview
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.blueLight.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmittingReview
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : Text(
                        '⭐ Enviar Avaliação',
                        style: TextStyle(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _centeredMessage(IconData icon, String message, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.blueMedium)),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM BAR ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(bool isDesktop, bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 20, 10, isMobile ? 16 : 20, isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.creamDark)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Preço estimado',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.blueLight)),
                  const SizedBox(height: 2),
                  Text(
                    widget.provider != null
                        ? 'MT ${widget.provider!.price.toStringAsFixed(0)}'
                        : 'MT 1.500 - 3.500',
                    style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.provider != null) {
                    Navigator.pop(context, widget.provider);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Solicitação enviada!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ));
                  }
                },
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: Text(
                  widget.provider != null ? 'Solicitar' : 'Contato',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── OPÇÕES ─────────────────────────────────────────────────────────────────
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.creamDark,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.error),
              title: const Text('Reportar Prestador',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  'Reportar Prestador',
                  'Tem certeza que deseja reportar este prestador?',
                  'Reportar',
                  () => _showSuccessMessage('Prestador reportado'),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined, color: AppColors.error),
              title: const Text('Bloquear Prestador',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  'Bloquear Prestador',
                  'Tem certeza que deseja bloquear este prestador?',
                  'Bloquear',
                  () => _showSuccessMessage('Prestador bloqueado'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
      String title, String content, String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title,
            style: const TextStyle(color: AppColors.primaryBlue, fontSize: 18)),
        content: Text(content,
            style: const TextStyle(color: AppColors.blueMedium, fontSize: 14)),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.blueMedium))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── UTILS ──────────────────────────────────────────────────────────────────
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '2024';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan',
        'Fev',
        'Mar',
        'Abr',
        'Mai',
        'Jun',
        'Jul',
        'Ago',
        'Set',
        'Out',
        'Nov',
        'Dez'
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
