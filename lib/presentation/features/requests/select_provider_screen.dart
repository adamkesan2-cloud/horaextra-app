// lib/presentation/features/requests/select_provider_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Melhorias:
//   • Agendamento direto na tela de seleção
//   • Filtro "Apenas Online"
//   • Ordenação por menor custo + badge de destaque
//   • Cancelar solicitação
//   • UI sem ícones decorativos, tipografia-first
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:horaextra_app/data/models/location/location_model.dart';
import 'package:horaextra_app/data/models/service/location_service.dart';
import 'package:horaextra_app/presentation/features/requests/request_tracking_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/data/models/provider/provider_selection_model.dart';
import 'package:horaextra_app/data/models/service/service_model.dart';
import 'package:horaextra_app/presentation/features/profile/view/provider_profile_screen.dart';

class SelectProviderScreen extends StatefulWidget {
  final ServiceModel service;
  final DateTime? scheduledDate;
  final String? observations;
  final Map<String, dynamic>? location;
  final bool isUrgent;
  final int quantity;

  const SelectProviderScreen({
    super.key,
    required this.service,
    this.scheduledDate,
    this.observations,
    this.location,
    this.isUrgent = false,
    this.quantity = 1,
  });

  @override
  State<SelectProviderScreen> createState() => _SelectProviderScreenState();
}

class _SelectProviderScreenState extends State<SelectProviderScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSending = false;
  String _sortBy = 'match';
  bool _onlineOnly = false;
  List<ProviderSelectionModel> _providers = [];
  String? _errorMessage;
  LatLng? _currentPosition;
  String _address = 'Maputo, Moçambique';

  // Agendamento interno
  DateTime? _scheduledDate;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.scheduledDate;
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProviders());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  double _calculateProviderPrice(ProviderSelectionModel p) =>
      p.price * widget.quantity * (widget.isUrgent ? 1.2 : 1);

  double _calculateTotal() => _providers
      .where((p) => p.isSelected)
      .fold(0.0, (s, p) => s + _calculateProviderPrice(p));

  double _calculateBudget() {
    final selected = _providers.where((p) => p.isSelected).toList();
    if (selected.isEmpty) return 0;
    return selected.fold(0.0, (s, p) => s + _calculateProviderPrice(p)) /
        selected.length;
  }

  Future<void> _loadProviders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      LatLng userLocation;
      String address = 'Maputo, Moçambique';

      if (widget.location != null &&
          widget.location!['latitude'] != null) {
        userLocation = LatLng(
          widget.location!['latitude'] as double,
          widget.location!['longitude'] as double,
        );
        address = widget.location!['address']?.toString() ?? address;
      } else if (kIsWeb) {
        userLocation = const LatLng(-25.9692, 32.5732);
      } else {
        final loc = await LocationService.getCurrentLocationWithAddress();
        userLocation = loc.position;
        address = loc.address;
      }

      final result = await appProvider.findNearbyProviders(
        serviceId: widget.service.id,
        clientLatitude: userLocation.latitude,
        clientLongitude: userLocation.longitude,
        maxDistance: 20,
      );

      if (!mounted) return;
      setState(() {
        _providers = result;
        _isLoading = false;
        _currentPosition = userLocation;
        _address = address;
      });
      _sortProviders();
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar prestadores: $e';
      });
    }
  }

  void _sortProviders() {
    setState(() {
      switch (_sortBy) {
        case 'match':
          _providers.sort((a, b) => b.matchScore.compareTo(a.matchScore));
          break;
        case 'distance':
          _providers.sort((a, b) => a.distance.compareTo(b.distance));
          break;
        case 'price':
          _providers.sort((a, b) => a.price.compareTo(b.price));
          break;
        case 'rating':
          _providers.sort((a, b) => b.rating.compareTo(a.rating));
          break;
      }
    });
  }

  List<ProviderSelectionModel> get _filteredProviders =>
      _onlineOnly ? _providers.where((p) => p.isOnline).toList() : _providers;

  int get _selectedCount => _providers.where((p) => p.isSelected).length;

  void _toggleSelection(int index) {
    setState(() {
      _providers[index] =
          _providers[index].copyWith(isSelected: !_providers[index].isSelected);
    });
  }

  void _toggleSelectAll() {
    final allSelected = _selectedCount == _filteredProviders.length;
    setState(() {
      for (final p in _filteredProviders) {
        final idx = _providers.indexOf(p);
        _providers[idx] = _providers[idx].copyWith(isSelected: !allSelected);
      }
    });
  }

  // ── Agendamento ────────────────────────────────────────────────────────────
  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _scheduledDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _fmtDate(DateTime d) {
    final days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]} às '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}h';
  }

  // ── Cancelar ───────────────────────────────────────────────────────────────
  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar solicitação',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue)),
        content: const Text(
            'Tem certeza que deseja cancelar esta solicitação?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não',
                  style: TextStyle(color: AppColors.primaryBlue))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final cheapest = _providers.isNotEmpty
        ? _providers.reduce((a, b) => a.price < b.price ? a : b)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(isDesktop),
      body: _isLoading
          ? _buildLoading()
          : _errorMessage != null
              ? _buildError()
              : Column(
                  children: [
                    _buildScheduleBar(),
                    _buildFilterBar(isDesktop),
                    Expanded(
                      child: _filteredProviders.isEmpty
                          ? _buildEmptyState(isDesktop)
                          : FadeTransition(
                              opacity: _fadeAnim,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    isDesktop ? 20 : 16,
                                    12,
                                    isDesktop ? 20 : 16,
                                    isDesktop ? 20 : 16),
                                itemCount: _filteredProviders.length,
                                itemBuilder: (ctx, i) => _buildProviderCard(
                                    _filteredProviders[i], cheapest, isDesktop),
                              ),
                            ),
                    ),
                    _buildFooter(isDesktop),
                  ],
                ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryBlue),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Escolher Prestador',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue)),
          Text(widget.service.name,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.blueMedium),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.border, height: 1),
      ),
      actions: [
        if (widget.quantity > 1)
          _appBarChip('${widget.quantity}x', AppColors.primaryBlue),
        if (widget.isUrgent)
          _appBarChip('URGENTE', AppColors.error),
        TextButton(
          onPressed: _cancelRequest,
          child: const Text('Cancelar',
              style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
        IconButton(
          icon:
              const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue),
          onPressed: _loadProviders,
        ),
      ],
    );
  }

  Widget _appBarChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ── Barra de agendamento ───────────────────────────────────────────────────
  Widget _buildScheduleBar() {
    return GestureDetector(
      onTap: _pickSchedule,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _scheduledDate != null
              ? AppColors.primaryBlue.withOpacity(0.05)
              : AppColors.white,
          border: Border(
            bottom: BorderSide(
              color: _scheduledDate != null
                  ? AppColors.primaryBlue.withOpacity(0.3)
                  : AppColors.border,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _scheduledDate != null
                        ? 'Agendado para'
                        : 'Agendar serviço',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _scheduledDate != null
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (_scheduledDate != null)
                    Text(
                      _fmtDate(_scheduledDate!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    )
                  else
                    const Text(
                      'Toque para escolher data e hora',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            if (_scheduledDate != null)
              GestureDetector(
                onTap: () => setState(() => _scheduledDate = null),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.2)),
                  ),
                  child: const Text('Remover',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600)),
                ),
              )
            else
              const Text('Escolher →',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue)),
          ],
        ),
      ),
    );
  }

  // ── Filtros ────────────────────────────────────────────────────────────────
  Widget _buildFilterBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Ordenação
          _filterDropdown(),
          const SizedBox(width: 10),
          // Online Only toggle
          GestureDetector(
            onTap: () => setState(() => _onlineOnly = !_onlineOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _onlineOnly
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.creamLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _onlineOnly
                      ? AppColors.success
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _onlineOnly
                          ? AppColors.success
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _onlineOnly
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Selecionar todos
          if (_filteredProviders.isNotEmpty)
            GestureDetector(
              onTap: _toggleSelectAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.creamLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _selectedCount == _filteredProviders.length
                      ? 'Limpar'
                      : 'Todos',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const Spacer(),
          Text(
            '${_filteredProviders.length} prestador${_filteredProviders.length != 1 ? 'es' : ''}',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: _sortBy,
        underline: const SizedBox(),
        isDense: true,
        icon: const Icon(Icons.expand_more,
            color: AppColors.primaryBlue, size: 18),
        style: const TextStyle(
            fontSize: 12,
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600),
        items: const [
          DropdownMenuItem(value: 'match', child: Text('Melhor match')),
          DropdownMenuItem(value: 'price', child: Text('Menor preço')),
          DropdownMenuItem(value: 'distance', child: Text('Mais próximo')),
          DropdownMenuItem(value: 'rating', child: Text('Melhor avaliado')),
        ],
        onChanged: (v) {
          if (v != null) {
            setState(() => _sortBy = v);
            _sortProviders();
          }
        },
      ),
    );
  }

  // ── Card de prestador ──────────────────────────────────────────────────────
  Widget _buildProviderCard(
      ProviderSelectionModel provider,
      ProviderSelectionModel? cheapest,
      bool isDesktop) {
    final totalPrice = _calculateProviderPrice(provider);
    final isCheapest =
        cheapest != null && provider.id == cheapest.id && _providers.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: provider.isSelected
              ? AppColors.primaryBlue
              : isCheapest
                  ? AppColors.success.withOpacity(0.4)
                  : AppColors.border,
          width: provider.isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (provider.isSelected)
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.12),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final idx = _providers.indexOf(provider);
            _toggleSelection(idx);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 16 : 14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Checkbox visual
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isSelected
                            ? AppColors.primaryBlue
                            : Colors.transparent,
                        border: Border.all(
                          color: provider.isSelected
                              ? AppColors.primaryBlue
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: provider.isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 13)
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.providerGradient,
                          ),
                          child: ClipOval(
                            child: provider.photoUrl.isNotEmpty
                                ? Image.network(provider.photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatar(provider.name, 50))
                                : _avatar(provider.name, 50),
                          ),
                        ),
                        // Online dot
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: provider.isOnline
                                  ? AppColors.success
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  provider.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Match score
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.creamLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  '${provider.matchScore.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '★ ${provider.rating.toStringAsFixed(1)}  ·  '
                            '${provider.distance.toStringAsFixed(1)} km  ·  '
                            '${provider.completedJobs} serviços',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          if (provider.specialties.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                provider.specialties.take(2).join(' · '),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.blueMedium),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Rodapé: preço + badges + botões
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Preço estimado',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'MT ${totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            if (widget.quantity > 1)
                              Text(
                                ' (${widget.quantity}×)',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                        // Badges
                        Row(
                          children: [
                            if (isCheapest)
                              _badge('MENOR PREÇO', AppColors.success),
                            if (provider.isOnline) ...[
                              if (isCheapest) const SizedBox(width: 6),
                              _badge('ONLINE', AppColors.success),
                            ] else
                              _badge('OFFLINE', Colors.grey),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Ver perfil
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProviderProfileScreen.fromProvider(provider),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side:
                            const BorderSide(color: AppColors.primaryBlue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Perfil',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),

                    // Selecionar
                    ElevatedButton(
                      onPressed: () {
                        final idx = _providers.indexOf(provider);
                        _toggleSelection(idx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: provider.isSelected
                            ? AppColors.success
                            : AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(
                        provider.isSelected ? 'Selecionado' : 'Selecionar',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4)),
    );
  }

  Widget _avatar(String name, double size) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDesktop) {
    final total = _calculateTotal();
    return Container(
      padding: EdgeInsets.fromLTRB(
          isDesktop ? 20 : 16,
          12,
          isDesktop ? 20 : 16,
          isDesktop ? 24 : 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
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
                  Text(
                    '$_selectedCount selecionado${_selectedCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue),
                  ),
                  if (_selectedCount > 0)
                    Text(
                      'Total: MT ${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  if (_scheduledDate != null)
                    Text(
                      _fmtDate(_scheduledDate!),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.info),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _selectedCount > 0
                ? ElevatedButton(
                    onPressed: _isSending ? null : _sendRequests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _scheduledDate != null
                                ? 'Agendar'
                                : 'Enviar Solicitações',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                  )
                : OutlinedButton(
                    onPressed: _cancelRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
          ],
        ),
      ),
    );
  }

  // ── Enviar ─────────────────────────────────────────────────────────────────
  Future<void> _sendRequests() async {
    final selected = _providers.where((p) => p.isSelected).toList();
    if (selected.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final budget = _calculateBudget();

      final requestId = await appProvider.createRequest(
        serviceId: widget.service.id,
        clientId: authProvider.currentUser?.id ?? '',
        clientName: authProvider.currentUser?.name ?? 'Cliente',
        providerIds: selected.map((p) => p.id).toList(),
        location: LocationModel(
          latitude: _currentPosition?.latitude ?? -25.9692,
          longitude: _currentPosition?.longitude ?? 32.5732,
          address: _address,
        ),
        budget: budget,
        scheduledDate: _scheduledDate,
        observations: widget.observations,
      );

      if (requestId != null && requestId.isNotEmpty) {
        if (!kIsWeb) {
          RealtimeWsService().sendServiceRequest(
            requestId: requestId,
            selectedProviderIds: selected.map((p) => p.id).toList(),
            serviceName: widget.service.name,
            clientName: authProvider.currentUser?.name ?? 'Cliente',
            location: {
              'latitude': _currentPosition?.latitude ?? -25.9692,
              'longitude': _currentPosition?.longitude ?? 32.5732,
              'address': _address,
            },
          );
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RequestTrackingScreen(
                serviceName: widget.service.name,
                selectedProviders: selected,
                isUrgent: widget.isUrgent,
                scheduledDate: _scheduledDate,
                requestId: requestId,
                quantity: widget.quantity,
              ),
            ),
          );
        }
      } else {
        throw Exception('Falha ao criar pedido');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primaryBlue),
          SizedBox(height: 16),
          Text('A procurar prestadores próximos...',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage ?? 'Erro desconhecido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProviders,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDesktop) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _onlineOnly
                  ? 'Nenhum prestador online\nneste momento'
                  : 'Nenhum prestador encontrado\nna sua área',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 12),
            if (_onlineOnly)
              GestureDetector(
                onTap: () => setState(() => _onlineOnly = false),
                child: const Text('Mostrar todos os prestadores →',
                    style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProviders,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}