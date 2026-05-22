// lib/presentation/features/map/client_map_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';
import 'package:horaextra_app/core/services/realtime_ws_service.dart';
import 'package:horaextra_app/data/models/service/location_service.dart'
    hide LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class ClientMapScreen extends StatefulWidget {
  final String? requestId;
  final String? providerId;
  final String? providerName;
  final double? clientLat;
  final double? clientLng;

  const ClientMapScreen({
    super.key,
    this.requestId,
    this.providerId,
    this.providerName,
    this.clientLat,
    this.clientLng,
  });

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  LatLng _clientPos = const LatLng(-25.9692, 32.5732);
  LatLng? _providerPos;
  String? _providerName;
  String _clientAddress = 'Maputo, Moçambique';
  String _clientNeighborhood = 'Central';
  List<LatLng> _routePoints = [];
  double _routeKm = 0;
  double _routeMin = 0;
  String _status = 'accepted';
  bool _loading = true;
  bool _isOnline = true;
  bool _mapReady = false;
  bool _isProcessing = false;
  Timer? _locationTimer;
  Timer? _routeUpdateTimer;
  final List<StreamSubscription> _subs = [];

  static const Color _routeBlue = Color(0xFF2196F3);
  static const Color _providerGreen = Color(0xFF4CAF50);
  static const Color _clientAmber = Color(0xFFFFC107);
  static const Color _errorRed = Color(0xFFEF5350);

  @override
  void initState() {
    super.initState();
    _providerName = widget.providerName;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
  }

  Future<void> _init() async {
    await _getClientLocation();
    await _loadRequestData();
    _listenToWebSocket();
    _startLocationTracking();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _getClientLocation() async {
    try {
      final loc = await LocationService.getCurrentLocationWithAddress();
      if (mounted) {
        setState(() {
          _clientPos = loc.position;
          _clientAddress = loc.address;
        });
        await _getNeighborhood(_clientPos.latitude, _clientPos.longitude);
      }
    } catch (e) {
      debugPrint('Erro localização: $e');
      await _getNeighborhood(_clientPos.latitude, _clientPos.longitude);
    }
  }

  Future<void> _getNeighborhood(double lat, double lng) async {
    try {
      final neighborhood =
          await LocationService.getNeighborhood(LatLng(lat, lng));
      if (mounted && neighborhood.isNotEmpty) {
        setState(() => _clientNeighborhood = neighborhood);
      }
    } catch (e) {
      debugPrint('Erro ao obter bairro: $e');
      setState(() => _clientNeighborhood = _getNeighborhoodFallback(lat, lng));
    }
  }

  String _getNeighborhoodFallback(double lat, double lng) {
    if (lat > -25.98 && lat < -25.95 && lng > 32.55 && lng < 32.62)
      return 'Central';
    if (lat > -25.96 && lat < -25.93 && lng > 32.58 && lng < 32.65)
      return 'Sommerschield';
    if (lat > -25.99 && lat < -25.96 && lng > 32.55 && lng < 32.60)
      return 'Polana';
    if (lat > -25.97 && lat < -25.94 && lng > 32.62 && lng < 32.68)
      return 'Costa do Sol';
    return 'Maputo';
  }

  Future<void> _loadRequestData() async {
    final ap = Provider.of<AppProvider>(context, listen: false);
    try {
      if (widget.providerId != null) {
        await _loadProviderData(ap);
      } else if (widget.requestId != null) {
        await _loadRequestById(ap);
      } else if (widget.clientLat != null && widget.clientLng != null) {
        setState(() {
          _clientPos = LatLng(widget.clientLat!, widget.clientLng!);
        });
        await _getNeighborhood(widget.clientLat!, widget.clientLng!);
      }
    } catch (e) {
      debugPrint('Erro loadRequestData: $e');
    }
  }

  Future<void> _loadProviderData(AppProvider ap) async {
    final providers = await ap.getProvidersNearby(
      latitude: _clientPos.latitude,
      longitude: _clientPos.longitude,
    );
    if (providers.isNotEmpty && mounted) {
      final provider = providers.firstWhere(
        (p) => p.id == widget.providerId,
        orElse: () => providers.first,
      );
      setState(() {
        _providerPos = LatLng(provider.latitude, provider.longitude);
        _providerName = _providerName ?? provider.name;
      });
      await _calculateRoute();
    }
  }

  Future<void> _loadRequestById(AppProvider ap) async {
    await ap.loadClientRequests(forceRefresh: true);
    final requests = ap.clientRequests;
    if (requests.isEmpty) return;
    final request = requests.firstWhere(
      (r) => r.id == widget.requestId,
      orElse: () => requests.first,
    );
    if (request.providerId != null &&
        request.providerId!.isNotEmpty &&
        mounted) {
      final providers = await ap.getProvidersNearby(
        latitude: _clientPos.latitude,
        longitude: _clientPos.longitude,
      );
      if (providers.isNotEmpty) {
        final provider = providers.firstWhere(
          (p) => p.id == request.providerId,
          orElse: () => providers.first,
        );
        setState(() {
          _providerPos = LatLng(provider.latitude, provider.longitude);
          _providerName = _providerName ?? provider.name;
          _status = request.status;
        });
        await _calculateRoute();
      }
    }
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_providerPos != null && mounted) _calculateRoute();
    });
    _routeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_providerPos != null && mounted) _calculateRoute(forceRefresh: true);
    });
  }

  void _listenToWebSocket() {
    _subs.add(RealtimeWsService().providerLocations.listen((data) {
      if (!mounted) return;
      final providerId = data['providerId']?.toString() ?? '';
      if (providerId == widget.providerId || providerId.isNotEmpty) {
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() => _providerPos = LatLng(lat, lng));
          _calculateRoute();
          if (_providerPos != null && _status == 'accepted') {
            final dist = _haversine(_providerPos!, _clientPos);
            if (dist < 0.1) setState(() => _status = 'arrived');
          }
        }
      }
    }));

    _subs.add(RealtimeWsService().providerOnline.listen((data) {
      if (data['id']?.toString() == widget.providerId && mounted) {
        setState(() => _isOnline = true);
      }
    }));

    _subs.add(RealtimeWsService().providerOffline.listen((data) {
      if (data['id']?.toString() == widget.providerId && mounted) {
        setState(() => _isOnline = false);
      }
    }));

    _subs.add(RealtimeWsService().serviceCompleted.listen((data) {
      if (!mounted) return;
      _showSnackbar('Serviço concluído com sucesso! 🎉', _providerGreen);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }));
  }

  Future<void> _calculateRoute({bool forceRefresh = false}) async {
    if (_providerPos == null) return;
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      final route = await ap.calculateRoute(
        from: _providerPos!,
        to: _clientPos,
      );
      if (mounted && route != null) {
        setState(() {
          _routePoints = route.points;
          _routeKm = route.distanceKm;
          _routeMin = route.durationMin;
        });
        _fitCameraToRoute();
      }
    } catch (e) {
      debugPrint('Erro rota: $e');
      if (mounted && _providerPos != null) {
        setState(() {
          _routePoints = _straightLine(_providerPos!, _clientPos);
          _routeKm = _haversine(_providerPos!, _clientPos);
          _routeMin = _routeKm * 3;
        });
      }
    }
  }

  void _fitCameraToRoute() {
    if (_mapReady && _routePoints.isNotEmpty && _providerPos != null) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds(_providerPos!, _clientPos),
          padding: const EdgeInsets.fromLTRB(60, 190, 60, 80),
        ));
      } catch (_) {}
    }
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.pow(math.sin(dLon / 2), 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  List<LatLng> _straightLine(LatLng from, LatLng to) => List.generate(
        31,
        (i) => LatLng(
          from.latitude + (to.latitude - from.latitude) * i / 30,
          from.longitude + (to.longitude - from.longitude) * i / 30,
        ),
      );

  List<Marker> _buildArrowMarkers() {
    if (_routePoints.length < 4) return [];
    final arrows = <Marker>[];
    final step = math.max(3, _routePoints.length ~/ 6);
    for (int i = step; i < _routePoints.length - 1; i += step) {
      final p1 = _routePoints[i];
      final p2 = _routePoints[i + 1];
      final angle = math.atan2(
        p2.longitude - p1.longitude,
        p2.latitude - p1.latitude,
      );
      arrows.add(Marker(
        point: p1,
        width: 24,
        height: 24,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _routeBlue.withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.navigation_rounded,
                color: Colors.white, size: 14),
          ),
        ),
      ));
    }
    return arrows;
  }

  void _markProviderArrived() {
    setState(() {
      _status = 'in_progress';
      _routePoints = [];
    });
    _showSnackbar('Serviço iniciado! Prestador está consigo.', _providerGreen);
  }

  Future<void> _finalizeService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1e2638),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: _providerGreen.withOpacity(0.4), width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _providerGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.done_all_rounded, color: _providerGreen, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Finalizar Serviço',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'O serviço foi concluído com sucesso?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Confirmar',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _providerGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      if (widget.requestId != null) {
        await ap.completeService(widget.requestId!);
      }
      if (mounted) {
        _showSnackbar('Serviço finalizado! Obrigado 🎉', _providerGreen);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Erro ao finalizar: $e', _errorRed);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _centerOnClient() {
    if (_mapReady) _mapController.move(_clientPos, 16);
  }

  void _centerOnProvider() {
    if (_providerPos != null && _mapReady)
      _mapController.move(_providerPos!, 16);
  }

  void _fitBoth() {
    if (_providerPos == null || !_mapReady) return;
    try {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(_providerPos!, _clientPos),
        padding: const EdgeInsets.fromLTRB(60, 190, 60, 80),
      ));
    } catch (_) {}
  }

  bool get _showActionPanel => _status == 'arrived' || _status == 'in_progress';

  @override
  void dispose() {
    _locationTimer?.cancel();
    _routeUpdateTimer?.cancel();
    for (final s in _subs) s.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a2035),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)))
          : Stack(children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _clientPos,
                  initialZoom: 14,
                  minZoom: 5,
                  maxZoom: 19,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _mapController.move(_clientPos, 14);
                    });
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
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _routePoints,
                        color: _routeBlue.withOpacity(0.15),
                        strokeWidth: 18,
                      ),
                      Polyline(
                        points: _routePoints,
                        color: _routeBlue,
                        strokeWidth: 5.5,
                        borderColor: Colors.white.withOpacity(0.3),
                        borderStrokeWidth: 2,
                      ),
                    ]),
                  if (_routePoints.isNotEmpty)
                    MarkerLayer(markers: _buildArrowMarkers()),
                  if (_providerPos != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _providerPos!,
                        width: 130,
                        height: 58,
                        alignment: Alignment.bottomCenter,
                        child: _buildProviderMarker(),
                      ),
                    ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: _clientPos,
                      width: 130,
                      height: 58,
                      alignment: Alignment.bottomCenter,
                      child: _buildClientMarker(),
                    ),
                  ]),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _buildTopBar()),
              ),
              Positioned(
                top: 90,
                left: 12,
                right: 12,
                child: _buildInfoCard(),
              ),
              Positioned(
                bottom: _showActionPanel ? 160 : 24,
                right: 12,
                child: Column(children: [
                  _fab(Icons.fit_screen_rounded, _routeBlue, _fitBoth),
                  const SizedBox(height: 8),
                  _fab(Icons.home_rounded, _clientAmber, _centerOnClient),
                  if (_providerPos != null) ...[
                    const SizedBox(height: 8),
                    _fab(Icons.directions_car_filled, _providerGreen,
                        _centerOnProvider),
                  ],
                ]),
              ),
              if (_showActionPanel)
                Positioned(
                    bottom: 0, left: 0, right: 0, child: _buildActionPanel()),
            ]),
    );
  }

  Widget _buildProviderMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1422).withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: _providerGreen.withOpacity(0.7), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PRESTADOR',
                style: TextStyle(
                    color: _providerGreen,
                    fontSize: 7,
                    fontWeight: FontWeight.w900),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  _providerName ?? '...',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Transform.scale(
          scale: _status == 'accepted' ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _providerGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: _providerGreen.withOpacity(0.5), blurRadius: 6)
              ],
            ),
            child: const Icon(Icons.directions_car_filled,
                color: Colors.white, size: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildClientMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1422).withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _clientAmber.withOpacity(0.7), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DESTINO',
                style: TextStyle(
                    color: _clientAmber,
                    fontSize: 7,
                    fontWeight: FontWeight.w900),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  _clientNeighborhood,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _clientAmber,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: _clientAmber.withOpacity(0.5), blurRadius: 6)
            ],
          ),
          child: const Icon(Icons.location_on_rounded,
              color: Colors.white, size: 13),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.primaryBlue, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Acompanhar Prestador',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue),
              ),
              Text(
                _status == 'accepted'
                    ? 'A caminho...'
                    : _status == 'arrived'
                        ? 'Chegou! Confirme a chegada.'
                        : 'Serviço em andamento 🔧',
                style: TextStyle(
                  fontSize: 11,
                  color: _status == 'in_progress'
                      ? _providerGreen
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: (_isOnline ? _providerGreen : Colors.grey).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: _isOnline ? _providerGreen : Colors.grey,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              _isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _isOnline ? _providerGreen : Colors.grey,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(13),
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
      child: Column(children: [
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _status == 'in_progress' ? _providerGreen : _clientAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status == 'accepted'
                  ? 'Prestador a caminho 🚗'
                  : _status == 'arrived'
                      ? 'Prestador chegou! 🎉'
                      : 'Serviço em andamento 🔧',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF1a237e)),
            ),
          ),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          const Icon(Icons.person_rounded,
              size: 14, color: AppColors.blueMedium),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _providerName ?? 'A carregar...',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        Row(children: [
          const Icon(Icons.location_city_rounded,
              size: 14, color: AppColors.blueMedium),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _clientNeighborhood,
              style: const TextStyle(fontSize: 12, color: AppColors.blueMedium),
            ),
          ),
        ]),
        if (_routeKm > 0 && _status == 'accepted') ...[
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.route_rounded,
                  size: 14, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text(
                '${_routeKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue),
              ),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.grey.shade300,
              ),
              const Icon(Icons.access_time_rounded,
                  size: 14, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text(
                '${_routeMin.toStringAsFixed(0)} min',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildActionPanel() {
    final isArrived = _status == 'arrived';
    final accentColor = isArrived ? _clientAmber : _providerGreen;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1e2638),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
            top: BorderSide(color: accentColor.withOpacity(0.5), width: 2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, -6))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2)),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isArrived ? Icons.location_on_rounded : Icons.engineering_rounded,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isArrived
                      ? '${_providerName ?? 'Prestador'} chegou!'
                      : 'Serviço em andamento',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  isArrived
                      ? 'Confirme para iniciar o serviço'
                      : 'Toque em finalizar quando concluir',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : (isArrived ? _markProviderArrived : _finalizeService),
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    isArrived
                        ? Icons.check_circle_rounded
                        : Icons.done_all_rounded,
                    size: 20),
            label: Text(
              isArrived ? 'Confirmar Chegada' : 'Finalizar Serviço',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fab(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
