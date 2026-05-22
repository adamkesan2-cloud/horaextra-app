// lib/presentation/features/map/provider_map_screen.dart
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
import 'package:http/http.dart' as http;
import 'dart:convert';

class IncomingRequest {
  final String requestId;
  final String clientId;
  final String clientName;
  final String serviceName;
  final double clientLat;
  final double clientLng;
  final String status;
  String clientNeighborhood;

  IncomingRequest({
    required this.requestId,
    required this.clientId,
    required this.clientName,
    required this.serviceName,
    required this.clientLat,
    required this.clientLng,
    required this.status,
    this.clientNeighborhood = '',
  });

  factory IncomingRequest.fromJson(Map<String, dynamic> json,
      {String? status}) {
    final loc = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : <String, dynamic>{};
    return IncomingRequest(
      requestId: json['requestId']?.toString() ?? json['id']?.toString() ?? '',
      clientId:
          json['clientId']?.toString() ?? json['client_id']?.toString() ?? '',
      clientName: json['clientName']?.toString() ??
          json['client_name']?.toString() ??
          'Cliente',
      serviceName: json['serviceName']?.toString() ??
          json['service_name']?.toString() ??
          'Serviço',
      clientLat: (loc['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          -25.9692,
      clientLng: (loc['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          32.5732,
      status: status ?? json['status']?.toString() ?? 'pending',
    );
  }
}

class ProviderMapScreen extends StatefulWidget {
  final String? requestId;
  const ProviderMapScreen({super.key, this.requestId});

  @override
  State<ProviderMapScreen> createState() => _ProviderMapScreenState();
}

class _ProviderMapScreenState extends State<ProviderMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Timer? _locationTimer;
  Timer? _routeRefreshTimer;

  LatLng _myPos = LocationService.maputoCenter;
  String _myAddress = 'A obter localização...';
  String _myNeighborhood = '';
  bool _isOnline = true;
  bool _locating = true;
  bool _mapReady = false;
  bool _processingRequest = false;

  IncomingRequest? _activeRequest;
  IncomingRequest? _activeService;
  List<LatLng> _routePoints = [];
  double _routeKm = 0;
  double _routeMin = 0;
  final List<IncomingRequest> _pendingRequests = [];
  final List<StreamSubscription> _subs = [];

  static const Color _providerBlue = Color(0xFF1E88E5);
  static const Color _activeGreen = Color(0xFF4CAF50);
  static const Color _clientAmber = Color(0xFFFFC107);
  static const Color _errorRed = Color(0xFFEF5350);

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _init();
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _locationTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final loc = await LocationService.getCurrentLocationWithAddress();
    if (!mounted) return;
    setState(() {
      _myPos = loc.position;
      _myAddress = loc.address;
      _locating = false;
    });
    await _getNeighborhood(_myPos.latitude, _myPos.longitude);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ws = RealtimeWsService();

    await ws.connect(
      userId: auth.currentUser?.id ?? 'provider-anon',
      name: auth.currentUser?.name ?? 'Prestador',
      role: 'provider',
      lat: _myPos.latitude,
      lng: _myPos.longitude,
      isOnline: _isOnline,
    );

    await _loadActiveServices();
    _startGpsTracking();
    _setupWebSocketStreams();

    if (widget.requestId != null) {
      await _loadSpecificRequest(widget.requestId!);
    }
  }

  Future<void> _getNeighborhood(double lat, double lng) async {
    try {
      final neighborhood =
          await LocationService.getNeighborhood(LatLng(lat, lng));
      if (mounted && neighborhood.isNotEmpty) {
        setState(() => _myNeighborhood = neighborhood);
      } else {
        setState(() => _myNeighborhood = _getNeighborhoodFallback(lat, lng));
      }
    } catch (e) {
      debugPrint('Erro ao obter bairro: $e');
      setState(() => _myNeighborhood = _getNeighborhoodFallback(lat, lng));
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

  void _startGpsTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isOnline || !mounted) return;
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
      RealtimeWsService().sendLocation(pos.latitude, pos.longitude);
      if (_activeService != null) {
        await _fetchRoute(
            LatLng(_activeService!.clientLat, _activeService!.clientLng));
      }
      if (_mapReady && _activeRequest == null && _activeService == null) {
        _mapController.move(_myPos, 14);
      }
    });

    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_activeService != null && mounted) {
        _fetchRoute(
            LatLng(_activeService!.clientLat, _activeService!.clientLng));
      }
    });
  }

  void _setupWebSocketStreams() {
    final ws = RealtimeWsService();

    _subs.add(ws.newRequest.listen((data) {
      if (!mounted) return;
      final req = IncomingRequest.fromJson(data, status: 'pending');
      _getClientNeighborhood(req);
      setState(() {
        _pendingRequests.insert(0, req);
        if (_activeRequest == null && _activeService == null) _showRequest(req);
      });
      _showNotification(req);
    }));

    _subs.add(ws.requestResponse.listen((data) {
      if (!mounted) return;
      final requestId = data['requestId']?.toString() ?? '';
      final accepted = data['accepted'] == true;
      if (!accepted && _activeRequest?.requestId == requestId) {
        setState(() {
          _pendingRequests.removeWhere((r) => r.requestId == requestId);
          _activeRequest = null;
          _routePoints = [];
        });
        _showSnackbar(
            'Este pedido foi aceite por outro prestador.', _clientAmber);
      }
    }));

    _subs.add(ws.serviceCompleted.listen((data) {
      if (!mounted) return;
      final requestId = data['requestId']?.toString() ?? '';
      final clientName = data['clientName']?.toString() ?? 'Cliente';
      if (_activeService?.requestId == requestId) {
        setState(() {
          _activeService = null;
          _routePoints = [];
        });
        _showSnackbar(
            '$clientName concluiu o serviço! Bom trabalho 🎉', _activeGreen,
            duration: 8);
        if (_mapReady) _mapController.move(_myPos, 14);
      }
    }));
  }

  Future<void> _getClientNeighborhood(IncomingRequest req) async {
    try {
      final neighborhood = await LocationService.getNeighborhood(
          LatLng(req.clientLat, req.clientLng));
      if (mounted && neighborhood.isNotEmpty) {
        setState(() {
          req.clientNeighborhood = neighborhood;
        });
      }
    } catch (e) {
      debugPrint('Erro ao obter bairro do cliente: $e');
    }
  }

  Future<void> _loadSpecificRequest(String requestId) async {
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      final pending = await ap.getProviderPendingRequests(forceRefresh: true);
      if (pending.isEmpty) return;
      final request = pending.firstWhere((r) => r.id == requestId,
          orElse: () => pending.first);
      if (request.id.isNotEmpty && mounted) {
        final req = IncomingRequest(
          requestId: request.id,
          clientId: request.clientId,
          clientName: request.clientName,
          serviceName: request.serviceName,
          clientLat: request.clientLatitude,
          clientLng: request.clientLongitude,
          status: request.status,
        );
        await _getClientNeighborhood(req);
        setState(() {
          _activeService = req;
          _activeRequest = null;
        });
        await _fetchRoute(LatLng(req.clientLat, req.clientLng));
        if (_mapReady)
          _mapController.move(LatLng(req.clientLat, req.clientLng), 14);
      }
    } catch (e) {
      debugPrint('Erro loadSpecificRequest: $e');
    }
  }

  Future<void> _loadActiveServices() async {
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      final activeServices = await ap.getProviderActiveServices();
      if (activeServices.isNotEmpty && mounted) {
        final service = activeServices.first;
        final req = IncomingRequest(
          requestId: service.id,
          clientId: service.clientId,
          clientName: service.clientName,
          serviceName: service.serviceName,
          clientLat: service.clientLatitude,
          clientLng: service.clientLongitude,
          status: service.status,
        );
        await _getClientNeighborhood(req);
        setState(() {
          _activeService = req;
        });
        await _fetchRoute(LatLng(req.clientLat, req.clientLng));
      }
    } catch (e) {
      debugPrint('Erro loadActiveServices: $e');
    }
  }

  void _showSnackbar(String msg, Color color, {int duration = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      backgroundColor: color,
      duration: Duration(seconds: duration),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _showNotification(IncomingRequest req) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.notifications_active_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Novo pedido!',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text('${req.clientName} — ${req.serviceName}',
                  style: const TextStyle(fontSize: 12)),
              if (req.clientNeighborhood.isNotEmpty)
                Text('📍 ${req.clientNeighborhood}',
                    style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ]),
      backgroundColor: _clientAmber,
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () => _showRequest(req)),
    ));
  }

  Future<void> _showRequest(IncomingRequest req) async {
    setState(() {
      _activeRequest = req;
      _routePoints = [];
    });
    final clientPos = LatLng(req.clientLat, req.clientLng);
    if (_mapReady) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds(_myPos, clientPos),
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 340),
        ));
      } catch (_) {
        _mapController.move(
          LatLng((_myPos.latitude + clientPos.latitude) / 2,
              (_myPos.longitude + clientPos.longitude) / 2),
          13,
        );
      }
    }
    await _fetchRoute(clientPos);
  }

  Future<void> _fetchRoute(LatLng dest) async {
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      final url = '${ap.baseUrl}/api/route'
          '?fromLat=${_myPos.latitude}&fromLng=${_myPos.longitude}'
          '&toLat=${dest.latitude}&toLng=${dest.longitude}';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pts = (data['points'] as List)
            .map((p) => LatLng(
                (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
            .toList();
        setState(() {
          _routePoints = pts;
          _routeKm = (data['distanceKm'] as num).toDouble();
          _routeMin = (data['durationMin'] as num).toDouble();
        });
        return;
      }
    } catch (e) {
      debugPrint('Rota erro: $e');
    }
    if (mounted) {
      setState(() {
        _routePoints = _straight(_myPos, dest);
        _routeKm = _haversine(_myPos, dest);
        _routeMin = _routeKm * 3;
      });
    }
  }

  List<Marker> _buildArrowMarkers(Color color) {
    if (_routePoints.length < 4) return [];
    final arrows = <Marker>[];
    final step = math.max(3, _routePoints.length ~/ 6);
    for (int i = step; i < _routePoints.length - 1; i += step) {
      final p1 = _routePoints[i];
      final p2 = _routePoints[i + 1];
      final angle =
          math.atan2(p2.longitude - p1.longitude, p2.latitude - p1.latitude);
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
                color: color.withOpacity(0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5)),
            child: const Icon(Icons.navigation_rounded,
                color: Colors.white, size: 13),
          ),
        ),
      ));
    }
    return arrows;
  }

  Future<void> _acceptRequest(IncomingRequest req) async {
    setState(() => _processingRequest = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.acceptRequest(req.requestId);
      RealtimeWsService().respondToRequest(req.requestId, true);
      if (mounted) {
        setState(() {
          _activeService = req;
          _activeRequest = null;
          _pendingRequests.remove(req);
        });
        _showSnackbar('Pedido aceite! A caminho do cliente.', _activeGreen);
        await _fetchRoute(LatLng(req.clientLat, req.clientLng));
        if (_mapReady) {
          try {
            _mapController.fitCamera(CameraFit.bounds(
              bounds:
                  LatLngBounds(_myPos, LatLng(req.clientLat, req.clientLng)),
              padding: const EdgeInsets.fromLTRB(60, 120, 60, 340),
            ));
          } catch (_) {
            _mapController.move(LatLng(req.clientLat, req.clientLng), 14);
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackbar('Erro ao aceitar: $e', _errorRed);
    } finally {
      if (mounted) setState(() => _processingRequest = false);
    }
  }

  Future<void> _rejectRequest(IncomingRequest req) async {
    setState(() => _processingRequest = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.rejectRequest(req.requestId);
      RealtimeWsService().respondToRequest(req.requestId, false);
      if (mounted) {
        setState(() {
          _pendingRequests.remove(req);
          _activeRequest = null;
          _routePoints = [];
        });
        if (_pendingRequests.isNotEmpty) _showRequest(_pendingRequests.first);
        _showSnackbar('Pedido recusado.', _errorRed);
      }
    } catch (e) {
      debugPrint('Erro rejeitar: $e');
    } finally {
      if (mounted) setState(() => _processingRequest = false);
    }
  }

  Future<void> _completeService() async {
    if (_activeService == null) return;
    setState(() => _processingRequest = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.completeService(_activeService!.requestId);
      if (mounted) {
        setState(() {
          _activeService = null;
          _routePoints = [];
        });
        _showSnackbar('Serviço concluído com sucesso!', _activeGreen);
        if (_mapReady) _mapController.move(_myPos, 14);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Erro ao concluir: $e', _errorRed);
    } finally {
      if (mounted) setState(() => _processingRequest = false);
    }
  }

  Future<void> _cancelService() async {
    if (_activeService == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1e2638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancelar Serviço',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Tem certeza que deseja cancelar?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Cancelar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processingRequest = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      await ap.rejectRequest(_activeService!.requestId);
      if (mounted) {
        setState(() {
          _activeService = null;
          _routePoints = [];
        });
        _showSnackbar('Serviço cancelado.', _clientAmber);
      }
    } catch (e) {
      debugPrint('Erro cancelar: $e');
    } finally {
      if (mounted) setState(() => _processingRequest = false);
    }
  }

  void _toggleOnline() {
    final next = !_isOnline;
    setState(() => _isOnline = next);
    RealtimeWsService().setOnlineStatus(next);
    _showSnackbar(next ? 'Você está online' : 'Você está offline',
        next ? _activeGreen : Colors.grey.shade700,
        duration: 2);
  }

  void _centerOnClient() {
    if (!_mapReady) return;
    final dest = _activeService ?? _activeRequest;
    if (dest != null) {
      _mapController.move(LatLng(dest.clientLat, dest.clientLng), 16);
    }
  }

  void _fitBothMarkers() {
    if (!_mapReady || _routePoints.isEmpty) return;
    final dest = _activeService ?? _activeRequest;
    if (dest == null) return;
    try {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(_myPos, LatLng(dest.clientLat, dest.clientLng)),
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 340),
      ));
    } catch (_) {}
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

  List<LatLng> _straight(LatLng from, LatLng to) => List.generate(
        31,
        (i) => LatLng(
          from.latitude + (to.latitude - from.latitude) * i / 30,
          from.longitude + (to.longitude - from.longitude) * i / 30,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasActiveService = _activeService != null;
    final hasActiveRequest = _activeRequest != null && !hasActiveService;
    final routeColor = hasActiveService ? _activeGreen : _providerBlue;
    final dest = hasActiveService ? _activeService : _activeRequest;

    return Scaffold(
      backgroundColor: const Color(0xFF1a2035),
      body: _locating
          ? Center(child: CircularProgressIndicator(color: _providerBlue))
          : Stack(children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _myPos,
                  initialZoom: 14,
                  minZoom: 5,
                  maxZoom: 19,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _mapController.move(_myPos, 14);
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
                          color: routeColor.withOpacity(0.15),
                          strokeWidth: 18),
                      Polyline(
                        points: _routePoints,
                        color: routeColor,
                        strokeWidth: 5.5,
                        borderColor: Colors.white.withOpacity(0.3),
                        borderStrokeWidth: 2,
                      ),
                    ]),
                  if (_routePoints.isNotEmpty)
                    MarkerLayer(markers: _buildArrowMarkers(routeColor)),
                  if (dest != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(dest.clientLat, dest.clientLng),
                        width: 130,
                        height: 58,
                        alignment: Alignment.bottomCenter,
                        child: _buildClientMarker(dest, hasActiveService),
                      ),
                    ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: _myPos,
                      width: 130,
                      height: 58,
                      alignment: Alignment.bottomCenter,
                      child: _buildProviderMarker(hasActiveService, routeColor),
                    ),
                  ]),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(children: [
                      _topFab(Icons.arrow_back_rounded,
                          () => Navigator.pop(context),
                          color: _providerBlue),
                      const SizedBox(width: 8),
                      Expanded(child: _addressBar()),
                      const SizedBox(width: 8),
                      _onlineToggle(),
                    ]),
                  ),
                ),
              ),
              if (_pendingRequests.isNotEmpty &&
                  _activeRequest == null &&
                  _activeService == null)
                Positioned(
                  top: 76,
                  left: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => _showRequest(_pendingRequests.first),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _clientAmber,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: _clientAmber.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Row(children: [
                        const Icon(Icons.notifications_active_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_pendingRequests.length} novo(s) pedido(s) — Toque para ver',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white, size: 20),
                      ]),
                    ),
                  ),
                ),
              if (_routePoints.isNotEmpty &&
                  (hasActiveRequest || hasActiveService))
                Positioned(
                  top: (_pendingRequests.isNotEmpty && !hasActiveService)
                      ? 136
                      : 76,
                  left: 12,
                  right: 12,
                  child: _routeBanner(hasActiveService, routeColor, dest),
                ),
              Positioned(
                bottom: (hasActiveRequest || hasActiveService) ? 310 : 24,
                right: 12,
                child: Column(children: [
                  _topFab(Icons.my_location_rounded,
                      () => _mapController.move(_myPos, 15),
                      color: _providerBlue),
                  if (hasActiveService || hasActiveRequest) ...[
                    const SizedBox(height: 8),
                    _topFab(Icons.fit_screen_rounded, _fitBothMarkers,
                        color: routeColor),
                    const SizedBox(height: 8),
                    _topFab(Icons.person_pin_circle_rounded, _centerOnClient,
                        color: _clientAmber),
                  ],
                ]),
              ),
              Positioned(
                bottom: (hasActiveRequest || hasActiveService) ? 310 : 24,
                left: 12,
                child: _legendWidget(
                    hasActiveService, routeColor, _pendingRequests.length),
              ),
              if (hasActiveRequest)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _requestCard(_activeRequest!)),
              if (hasActiveService)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _activeServiceCard(_activeService!)),
            ]),
    );
  }

  Widget _buildClientMarker(IncomingRequest dest, bool hasActiveService) {
    final displayName = dest.clientNeighborhood.isNotEmpty
        ? dest.clientNeighborhood
        : dest.clientName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1422).withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: (hasActiveService ? _activeGreen : _clientAmber)
                    .withOpacity(0.7),
                width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasActiveService ? 'DESTINO' : 'CLIENTE',
                style: TextStyle(
                    color: hasActiveService ? _activeGreen : _clientAmber,
                    fontSize: 7,
                    fontWeight: FontWeight.w900),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  displayName,
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
          scale: !hasActiveService ? _pulseAnim.value : 1.0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: hasActiveService ? _activeGreen : _clientAmber,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: (hasActiveService ? _activeGreen : _clientAmber)
                        .withOpacity(0.5),
                    blurRadius: 6)
              ],
            ),
            child: Icon(
                hasActiveService
                    ? Icons.check_circle_rounded
                    : Icons.person_rounded,
                color: Colors.white,
                size: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderMarker(bool hasActiveService, Color routeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1422).withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: routeColor.withOpacity(0.7), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VOCÊ',
                style: TextStyle(
                    color: routeColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w900),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  _myNeighborhood.isNotEmpty ? _myNeighborhood : _myAddress,
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
            color: _isOnline ? routeColor : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color:
                      (_isOnline ? routeColor : Colors.grey).withOpacity(0.5),
                  blurRadius: 6)
            ],
          ),
          child: Icon(
              hasActiveService
                  ? Icons.directions_car_filled
                  : Icons.engineering_rounded,
              color: Colors.white,
              size: 13),
        ),
      ],
    );
  }

  Widget _topFab(IconData icon, VoidCallback onTap,
          {Color color = Colors.white}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1e2638).withOpacity(0.95),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Icon(icon, color: color, size: 21),
        ),
      );

  Widget _addressBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1e2638).withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Icon(Icons.location_on_rounded, color: _providerBlue, size: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _myNeighborhood.isNotEmpty ? _myNeighborhood : _myAddress,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );

  Widget _onlineToggle() => GestureDetector(
        onTap: _toggleOnline,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isOnline ? _activeGreen : Colors.grey.shade700,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                  color: (_isOnline ? _activeGreen : Colors.grey)
                      .withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(_isOnline ? 'Online' : 'Offline',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  Widget _legendWidget(
          bool hasActiveService, Color routeColor, int pendingCount) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1e2638).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(
                routeColor,
                hasActiveService
                    ? Icons.directions_car_filled
                    : Icons.engineering_rounded,
                hasActiveService ? 'Em serviço' : 'Você'),
            const SizedBox(height: 5),
            _dot(
                hasActiveService ? _activeGreen : _clientAmber,
                hasActiveService
                    ? Icons.check_circle_rounded
                    : Icons.person_rounded,
                hasActiveService ? 'Destino' : 'Cliente'),
            const SizedBox(height: 5),
            _dot(routeColor, Icons.navigation_rounded, 'Rota'),
            if (!hasActiveService && pendingCount > 0) ...[
              const SizedBox(height: 5),
              Text('$pendingCount pedido(s)',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70)),
            ],
          ],
        ),
      );

  Widget _dot(Color color, IconData icon, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, color: Colors.white, size: 13)),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ]);

  Widget _routeBanner(
          bool hasActiveService, Color routeColor, IncomingRequest? dest) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1e2638).withOpacity(0.97),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: routeColor.withOpacity(0.35), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: routeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                hasActiveService
                    ? Icons.directions_car_filled
                    : Icons.navigation_rounded,
                color: routeColor,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${_routeKm.toStringAsFixed(1)} km · ${_routeMin.toStringAsFixed(0)} min',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                dest?.clientName ?? '',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.5)),
              ),
              if (dest?.clientNeighborhood.isNotEmpty ?? false)
                Text(
                  '📍 ${dest!.clientNeighborhood}',
                  style: TextStyle(
                      fontSize: 10, color: routeColor.withOpacity(0.8)),
                ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: routeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text(hasActiveService ? 'Activo' : 'Pedido',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: routeColor)),
          ),
        ]),
      );

  Widget _requestCard(IncomingRequest req) {
    final dist = _haversine(_myPos, LatLng(req.clientLat, req.clientLng));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1e2638),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
            top: BorderSide(color: _clientAmber.withOpacity(0.6), width: 2)),
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
                borderRadius: BorderRadius.circular(2))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: _clientAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.notifications_active_rounded,
                  color: _clientAmber, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(req.serviceName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white)),
              const SizedBox(height: 3),
              Text('${req.clientName}',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withOpacity(0.6))),
              if (req.clientNeighborhood.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('📍 ${req.clientNeighborhood}',
                    style: TextStyle(
                        fontSize: 12, color: _clientAmber.withOpacity(0.8))),
              ],
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 13, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 3),
                Text(
                    '${dist.toStringAsFixed(1)} km · ~${(_routeMin > 0 ? _routeMin : dist * 3).toStringAsFixed(0)} min',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.45))),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _processingRequest ? null : () => _rejectRequest(req),
              style: OutlinedButton.styleFrom(
                foregroundColor: _errorRed,
                side: BorderSide(color: _errorRed.withOpacity(0.7)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Recusar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _processingRequest ? null : () => _acceptRequest(req),
              icon: _processingRequest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(_processingRequest ? 'A processar...' : 'Aceitar',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _activeGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _activeServiceCard(IncomingRequest service) {
    final dist =
        _haversine(_myPos, LatLng(service.clientLat, service.clientLng));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1e2638),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
            top: BorderSide(color: _activeGreen.withOpacity(0.6), width: 2)),
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
                borderRadius: BorderRadius.circular(2))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: _activeGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.engineering_rounded,
                  color: _activeGreen, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(service.serviceName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white)),
              const SizedBox(height: 3),
              Text('${service.clientName}',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withOpacity(0.6))),
              if (service.clientNeighborhood.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('📍 ${service.clientNeighborhood}',
                    style: TextStyle(
                        fontSize: 12, color: _activeGreen.withOpacity(0.8))),
              ],
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 13, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 3),
                Text('${dist.toStringAsFixed(1)} km',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.45))),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _activeGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('Em andamento',
                      style: TextStyle(
                          fontSize: 10,
                          color: _activeGreen,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _processingRequest ? null : _cancelService,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _errorRed,
                side: BorderSide(color: _errorRed.withOpacity(0.7)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _processingRequest ? null : _completeService,
              icon: _processingRequest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.done_all_rounded, size: 18),
              label: Text(
                  _processingRequest ? 'A processar...' : 'Concluir Serviço',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _activeGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
