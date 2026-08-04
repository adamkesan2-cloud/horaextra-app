// lib/presentation/features/map/client_map_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:horaextra_app/presentation/chat/chat_screen.dart';
import 'package:horaextra_app/presentation/features/requests/request_details_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:provider/provider.dart';

class ClientMapScreen extends StatefulWidget {
  final String? requestId;
  final String? providerId;
  final String? providerName;
  final List<Map<String, dynamic>>? acceptedProviders;
  final double? pricePerProvider;
  final bool isPriceDivided;
  final double? totalBudget;
  final String? serviceName;
  final int? quantity;

  const ClientMapScreen({
    super.key,
    this.requestId,
    this.providerId,
    this.providerName,
    this.acceptedProviders,
    this.pricePerProvider,
    this.isPriceDivided = false,
    this.totalBudget,
    this.serviceName,
    this.quantity = 1,
  });

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<Map<String, dynamic>> _providers = [];
  LatLng _currentPosition = const LatLng(-25.9692, 32.5732);
  LatLng _clientPosition = const LatLng(-25.9692, 32.5732);
  String _clientAddress = 'Maputo, Moçambique';

  Timer? _locationTimer;
  Timer? _routeTimer;
  final List<StreamSubscription> _wsSubs = [];

  bool _isLoading = true;
  bool _isServiceComplete = false;
  bool _isServiceStarted = false;
  bool _mapReady = false;
  String _serviceStatus =
      'pending'; // pending | accepted | in_progress | completed | cancelled

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initProviders();
    _listenToWsEvents();
    _getCurrentLocation();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initProviders() {
    if (widget.acceptedProviders != null &&
        widget.acceptedProviders!.isNotEmpty) {
      _providers.addAll(widget.acceptedProviders!.map((p) => {
            'id': p['id']?.toString() ?? '',
            'name': p['name']?.toString() ?? 'Prestador',
            'lat': p['lat'] as double? ?? p['latitude'] as double? ?? -25.9692,
            'lng': p['lng'] as double? ?? p['longitude'] as double? ?? 32.5732,
            'photo': p['photo']?.toString() ?? p['photo_url']?.toString() ?? '',
            'eta': p['eta'] as int? ?? 10,
            'distance': p['distance'] as double? ?? 0,
          }));
    } else if (widget.providerId != null && widget.providerName != null) {
      _providers.add({
        'id': widget.providerId,
        'name': widget.providerName,
        'lat': -25.9692,
        'lng': 32.5732,
        'photo': '',
        'eta': 10,
        'distance': 0,
      });
    }
    _isLoading = false;
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!kIsWeb) {
        // Tentar obter localização real no dispositivo
        // (implementar com location package se disponível)
      }
      setState(() {
        _currentPosition = const LatLng(-25.9692, 32.5732);
        _clientPosition = const LatLng(-25.9692, 32.5732);
        _clientAddress = 'Maputo, Moçambique';
      });
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
    }
  }

  void _listenToWsEvents() {
    _wsSubs.add(RealtimeWsService().providerLocations.listen((data) {
      final providerId = data['providerId']?.toString() ?? '';
      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;
      final eta = data['eta'] as int?;

      if (providerId.isNotEmpty && lat != null && lng != null) {
        setState(() {
          final index = _providers.indexWhere((p) => p['id'] == providerId);
          if (index != -1) {
            _providers[index]['lat'] = lat;
            _providers[index]['lng'] = lng;
            if (eta != null) _providers[index]['eta'] = eta;
            _providers[index]['distance'] = _calculateDistance(
              _clientPosition.latitude,
              _clientPosition.longitude,
              lat,
              lng,
            );
          }
        });
        _fitBounds();
      }
    }));

    _wsSubs.add(RealtimeWsService().requestResponse.listen((data) {
      final incomingRequestId = data['requestId']?.toString() ?? '';
      if (widget.requestId != null &&
          incomingRequestId.isNotEmpty &&
          incomingRequestId != widget.requestId) return;

      final accepted = data['accepted'] == true;
      final providerName = data['providerName']?.toString() ?? 'Prestador';
      final isFull = data['isFull'] as bool? ?? false;
      final acceptedCount = data['acceptedCount'] as int? ?? 0;
      final pricePerProvider = data['pricePerProvider'] as double? ?? 0;
      final acceptedProviders = data['acceptedProviders'] as List? ?? [];

      if (accepted && acceptedProviders.isNotEmpty) {
        setState(() {
          for (final p in acceptedProviders) {
            final pid = p['id']?.toString() ?? '';
            if (pid.isNotEmpty &&
                !_providers.any((existing) => existing['id'] == pid)) {
              _providers.add({
                'id': pid,
                'name': p['name']?.toString() ?? 'Prestador',
                'lat': p['latitude'] as double? ?? -25.9692,
                'lng': p['longitude'] as double? ?? 32.5732,
                'photo': p['photo_url']?.toString() ?? '',
                'eta': 10,
                'distance': 0,
              });
            }
          }
        });
        _fitBounds();
      }

      if (accepted && isFull) {
        setState(() => _serviceStatus = 'accepted');
        _showAcceptedBanner(providerName, acceptedCount, pricePerProvider);
      }
    }));

    _wsSubs.add(RealtimeWsService().selectionFinalized.listen((data) {
      final incomingRequestId = data['requestId']?.toString() ?? '';
      if (widget.requestId != null &&
          incomingRequestId.isNotEmpty &&
          incomingRequestId != widget.requestId) return;

      final providerCount = data['providerCount'] as int? ?? 0;
      final pricePerProvider = data['pricePerProvider'] as double? ?? 0;
      final acceptedProviders = data['acceptedProviders'] as List? ?? [];

      setState(() {
        for (final p in acceptedProviders) {
          final pid = p['id']?.toString() ?? '';
          if (pid.isNotEmpty &&
              !_providers.any((existing) => existing['id'] == pid)) {
            _providers.add({
              'id': pid,
              'name': p['name']?.toString() ?? 'Prestador',
              'lat': p['latitude'] as double? ?? -25.9692,
              'lng': p['longitude'] as double? ?? 32.5732,
              'photo': p['photo_url']?.toString() ?? '',
              'eta': 10,
              'distance': 0,
            });
          }
        }
        _serviceStatus = 'accepted';
      });
      _fitBounds();
      _showSelectionFinalizedBanner(providerCount, pricePerProvider);
    }));

    _wsSubs.add(RealtimeWsService()
        .requestResponse
        .where((data) => data['started'] == true)
        .listen((data) {
      final incomingRequestId = data['requestId']?.toString() ?? '';
      if (widget.requestId != null &&
          incomingRequestId.isNotEmpty &&
          incomingRequestId != widget.requestId) return;

      setState(() {
        _serviceStatus = 'in_progress';
        _isServiceStarted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Serviço em andamento!'),
          backgroundColor: AppColors.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }));

    _wsSubs.add(RealtimeWsService().serviceCompleted.listen((data) {
      final incomingRequestId = data['requestId']?.toString() ?? '';
      if (widget.requestId != null &&
          incomingRequestId.isNotEmpty &&
          incomingRequestId != widget.requestId) return;

      if (mounted) {
        setState(() {
          _serviceStatus = 'completed';
          _isServiceComplete = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Serviço concluído com sucesso!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }));

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_providers.isNotEmpty &&
          !_isServiceComplete &&
          _serviceStatus != 'completed') {
        _updateProviderLocations();
      }
    });

    _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_providers.isNotEmpty && _serviceStatus == 'accepted') {
        setState(() {});
      }
    });
  }

  void _updateProviderLocations() {
    for (int i = 0; i < _providers.length; i++) {
      final provider = _providers[i];
      final lat = provider['lat'] as double;
      final lng = provider['lng'] as double;

      final dx = _clientPosition.latitude - lat;
      final dy = _clientPosition.longitude - lng;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance > 0.0001) {
        final speed = 0.0001 + math.Random().nextDouble() * 0.0002;
        final newLat = lat + (dx / distance) * speed;
        final newLng = lng + (dy / distance) * speed;

        RealtimeWsService().sendLocation(newLat, newLng);

        setState(() {
          provider['lat'] = newLat;
          provider['lng'] = newLng;
          final newDistance = _calculateDistance(
            _clientPosition.latitude,
            _clientPosition.longitude,
            newLat,
            newLng,
          );
          provider['distance'] = newDistance;
          provider['eta'] = (newDistance * 10).round() + 5;
        });
      }
    }
  }

  List<LatLng> _calculateRoutePoints(LatLng start, LatLng end) {
    final points = <LatLng>[start];
    const steps = 10;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lng = start.longitude + (end.longitude - start.longitude) * t;
      final curve = math.sin(t * math.pi) * 0.0005;
      points.add(LatLng(lat + curve, lng + curve * 0.5));
    }
    points.add(end);
    return points;
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  void _fitBounds() {
    if (!_mapReady) return;
    final points = <LatLng>[
      _clientPosition,
      ..._providers.map((p) => LatLng(p['lat'] as double, p['lng'] as double))
    ];
    if (points.length < 2) {
      _mapController.move(_clientPosition, 14);
      return;
    }
    try {
      double minLat = points.first.latitude, maxLat = points.first.latitude;
      double minLng = points.first.longitude, maxLng = points.first.longitude;
      for (final p in points) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 0.008, minLng - 0.008),
          LatLng(maxLat + 0.008, maxLng + 0.008),
        ),
        padding: const EdgeInsets.all(60),
      ));
    } catch (_) {}
  }

  void _showAcceptedBanner(
      String providerName, int count, double pricePerProvider) {
    if (!mounted) return;
    final message = count > 1
        ? '$count prestadores aceitaram! Valor dividido: MT ${pricePerProvider.toStringAsFixed(0)} cada'
        : '$providerName aceitou o pedido!';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _showSelectionFinalizedBanner(int count, double pricePerProvider) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '✅ Seleção finalizada! $count prestador(es) · MT ${pricePerProvider.toStringAsFixed(0)} cada',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
      backgroundColor: AppColors.primaryBlue,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  Future<void> _completeService() async {
    if (widget.requestId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Concluir Serviço',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content:
            const Text('Tem certeza que o serviço foi concluído com sucesso?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white),
            child: const Text('Sim, concluir'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.completeService(widget.requestId!);
      RealtimeWsService().notifyServiceCompleted(widget.requestId!);

      setState(() {
        _serviceStatus = 'completed';
        _isServiceComplete = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Serviço concluído com sucesso!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao concluir serviço: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _cancelService() async {
    if (widget.requestId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar Serviço',
            style:
                TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
        content: const Text('Tem certeza que deseja cancelar este serviço?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Não')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.cancelRequest(widget.requestId!);

      setState(() => _serviceStatus = 'cancelled');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Serviço cancelado'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao cancelar: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _routeTimer?.cancel();
    for (final sub in _wsSubs) {
      sub.cancel();
    }
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final hasMultipleProviders = _providers.length > 1;
    final isServiceActive =
        _serviceStatus == 'accepted' || _serviceStatus == 'in_progress';
    final isServiceCompleted = _serviceStatus == 'completed';
    final isServiceCancelled = _serviceStatus == 'cancelled';
    final showRoutes =
        _serviceStatus != 'completed' && _serviceStatus != 'cancelled';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(isDesktop, hasMultipleProviders),
      body: Stack(
        children: [
          if (!_isLoading)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition,
                initialZoom: 14,
                minZoom: 10,
                maxZoom: 18,
                onMapReady: () {
                  _mapReady = true;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _fitBounds());
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.horaextra.app',
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                if (showRoutes)
                  PolylineLayer(
                    polylines: _providers.map((provider) {
                      final routePoints = _calculateRoutePoints(
                        LatLng(provider['lat'] as double,
                            provider['lng'] as double),
                        _clientPosition,
                      );
                      return Polyline(
                        points: routePoints,
                        color: (hasMultipleProviders
                                ? Colors.orange
                                : AppColors.primaryBlue)
                            .withOpacity(0.5),
                        strokeWidth: 3,
                      );
                    }).toList(),
                  ),
                MarkerLayer(markers: [
                  Marker(
                    point: _clientPosition,
                    width: 120,
                    height: 50,
                    alignment: Alignment.bottomCenter,
                    child: _buildMarkerLabel(
                      title: 'Você',
                      subtitle: 'Cliente',
                      color: AppColors.primaryBlue,
                      icon: Icons.person_pin_circle_rounded,
                    ),
                  ),
                  for (int i = 0; i < _providers.length; i++)
                    Marker(
                      point: LatLng(_providers[i]['lat'] as double,
                          _providers[i]['lng'] as double),
                      width: 130,
                      height: 56,
                      alignment: Alignment.bottomCenter,
                      child: _buildMarkerLabel(
                        title: _providers[i]['name'] ?? 'Prestador ${i + 1}',
                        subtitle: _providerSnippet(
                            _providers[i], hasMultipleProviders),
                        color: hasMultipleProviders
                            ? Colors.orange
                            : AppColors.success,
                        icon: Icons.engineering_rounded,
                      ),
                    ),
                ]),
              ],
            ),
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue)),
          if (!_isLoading && !isServiceCompleted && !isServiceCancelled)
            _buildInfoCard(isDesktop, hasMultipleProviders),
          if (!_isLoading &&
              widget.isPriceDivided &&
              hasMultipleProviders &&
              isServiceActive)
            _buildPriceDividedCard(isDesktop),
          if (!_isLoading && isServiceActive) _buildActionButtons(isDesktop),
          if (isServiceCompleted) _buildCompletedCard(isDesktop),
          if (isServiceCancelled) _buildCancelledCard(isDesktop),
        ],
      ),
    );
  }

  String _providerSnippet(
      Map<String, dynamic> provider, bool hasMultipleProviders) {
    final eta = provider['eta'] as int? ?? 10;
    final distance = provider['distance'] as double? ?? 0;
    if (_isServiceComplete || _serviceStatus == 'completed')
      return '✅ Concluído';
    if (_serviceStatus == 'in_progress') return '🔄 Em andamento';
    if (widget.isPriceDivided && hasMultipleProviders) {
      return '💰 MT ${widget.pricePerProvider?.toStringAsFixed(0) ?? 0} · ${distance.toStringAsFixed(1)} km';
    }
    return '🚗 $eta min · ${distance.toStringAsFixed(1)} km';
  }

  Widget _buildMarkerLabel({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop, bool hasMultipleProviders) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_rounded, color: AppColors.primaryBlue),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasMultipleProviders
                ? 'Prestadores a Caminho'
                : 'Acompanhar Prestador',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue),
          ),
          if (_providers.isNotEmpty && !_isServiceComplete)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  hasMultipleProviders
                      ? '${_providers.length} prestadores ativos'
                      : _providers.first['name'] ?? 'Prestador',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.success),
                ),
              ],
            ),
          if (_isServiceComplete)
            const Text('✅ Serviço Concluído',
                style: TextStyle(fontSize: 11, color: AppColors.success)),
        ],
      ),
      actions: [
        if (_providers.isNotEmpty && !_isServiceComplete)
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    color: AppColors.primaryBlue, size: 14),
                const SizedBox(width: 4),
                Text('${_providers.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                        fontSize: 12)),
              ],
            ),
          ),
        if (widget.providerId != null && !_isServiceComplete)
          IconButton(
            icon: const Icon(Icons.chat_rounded, color: AppColors.primaryBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    requestId: widget.requestId ?? '',
                    providerId: widget.providerId!,
                    providerName: widget.providerName ?? 'Prestador',
                  ),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.info_outline_rounded,
              color: AppColors.primaryBlue),
          onPressed: () {
            if (widget.requestId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RequestDetailsScreen(requestId: widget.requestId!)),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard(bool isDesktop, bool hasMultipleProviders) {
    final eta = _providers.isNotEmpty
        ? (_providers
            .map((p) => p['eta'] as int? ?? 10)
            .reduce((a, b) => a < b ? a : b))
        : 10;

    final distance = _providers.isNotEmpty
        ? (_providers
            .map((p) => p['distance'] as double? ?? 0)
            .reduce((a, b) => a < b ? a : b))
        : 0;

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _serviceStatus == 'in_progress'
                        ? AppColors.primaryBlue.withOpacity(0.1)
                        : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _serviceStatus == 'in_progress'
                        ? Icons.sync_rounded
                        : Icons.directions_car_rounded,
                    color: _serviceStatus == 'in_progress'
                        ? AppColors.primaryBlue
                        : AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _serviceStatus == 'in_progress'
                            ? '🔄 Serviço em andamento'
                            : hasMultipleProviders
                                ? '${_providers.length} prestadores a caminho'
                                : '${_providers.first['name'] ?? 'Prestador'} a caminho',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasMultipleProviders
                            ? 'O mais próximo: ${distance.toStringAsFixed(1)} km · ~$eta min'
                            : '${distance.toStringAsFixed(1)} km · ~$eta min',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasMultipleProviders &&
                widget.isPriceDivided &&
                widget.pricePerProvider != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        color: AppColors.primaryBlue, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${_providers.length} prestadores · MT ${widget.pricePerProvider!.toStringAsFixed(0)} cada',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDividedCard(bool isDesktop) {
    return Positioned(
      top: isDesktop ? 130 : 120,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_alt_rounded,
                color: AppColors.success, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '💰 Valor dividido: MT ${widget.pricePerProvider?.toStringAsFixed(0) ?? 0} por prestador',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success),
              ),
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Opacity(
                opacity: _pulseAnimation.value,
                child: const Icon(Icons.check_circle,
                    color: AppColors.success, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isDesktop) {
    return Positioned(
      bottom: isDesktop ? 40 : 100,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_serviceStatus != 'completed')
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _cancelService,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancelar',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            if (_serviceStatus != 'completed') const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isServiceComplete ? null : _completeService,
                icon: _isServiceComplete
                    ? const Icon(Icons.check_circle_rounded,
                        color: Colors.white)
                    : const Icon(Icons.done_all_rounded, color: Colors.white),
                label: Text(
                  _isServiceComplete ? 'Serviço Concluído' : 'Concluir Serviço',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServiceComplete
                      ? AppColors.success
                      : AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(bool isDesktop) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Serviço Concluído!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success)),
            const SizedBox(height: 8),
            Text(widget.serviceName ?? 'Serviço',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            if (widget.isPriceDivided && widget.pricePerProvider != null) ...[
              const SizedBox(height: 8),
              Text(
                '💰 MT ${widget.pricePerProvider!.toStringAsFixed(0)} por prestador',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledCard(bool isDesktop) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.cancel_rounded,
                  color: AppColors.error, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Serviço Cancelado',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error)),
            const SizedBox(height: 8),
            Text(widget.serviceName ?? 'Serviço',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    );
  }
}
