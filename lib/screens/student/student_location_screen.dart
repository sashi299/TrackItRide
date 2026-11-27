import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../../services/supabase_service.dart';
import '../../services/tracking_interpolator.dart';
import '../../services/osrm_routing_service.dart';
import '../../widgets/live_eta_hud.dart';
import '../../supabase_config.dart';
import '../../shared/theme.dart';
import '../../shared/status_chip.dart';

/// Default College Campus Center (AITAM Tekkali: 18.5665, 84.1952)
const LatLng _kFallbackCenter = LatLng(SupabaseConfig.defaultCampusLat, SupabaseConfig.defaultCampusLng);

/// Student / Commuter Live Tracking Screen matching Figma S10 · Tracking · LIVE (7:1541)
class StudentLocationScreen extends StatefulWidget {
  final String? initialBusId;
  const StudentLocationScreen({super.key, this.initialBusId});

  @override
  State<StudentLocationScreen> createState() => _StudentLocationScreenState();
}

class _StudentLocationScreenState extends State<StudentLocationScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();
  Timer? _debounce;
  int _token = 0;
  List<Map<String, dynamic>> _buses = [];
  bool _loadingList = true;
  String? _listError;

  final List<Polyline> _polylines = [];
  final List<Marker> _markers = [];
  LatLng? _userLocation;
  final Location _location = Location();
  StreamSubscription<Map<String, dynamic>?>? _liveSub;
  StreamSubscription<LocationData>? _userSub;
  Timer? _ticker;

  // Uber-style smooth interpolation & tracking controller
  late final LiveVehicleAnimator _vehicleAnimator;
  bool _autoFollow = true;

  Map<String, dynamic>? _selected;
  DateTime? _lastUpdate;
  String _liveStatus = 'idle';
  double? _currentSpeedMps;
  String? _nextStopName;
  LatLng? _destinationLatLng;
  String? _destinationName;
  String? _etaString;
  bool _showBusListOverlay = false;

  // Road Routing & Live ETA HUD
  List<LatLng> _roadPoints = [];
  double? _roadDistanceMeters;
  double? _roadDurationSeconds;
  bool _isRoadGeometry = false;
  LatLng? _lastRoutedBusPos;
  bool _isRouting = false;

  // Stop Proximity 500m Geofence Alert
  LatLng? _targetStopLatLng;
  String? _targetStopName;
  bool _hasFiredProximityAlert = false;
  bool _showProximityBanner = false;
  bool _dismissedIssueBanner = false;

  @override
  void initState() {
    super.initState();
    _vehicleAnimator = LiveVehicleAnimator(vsync: this);
    _vehicleAnimator.addListener(_onVehicleAnimated);
    _searchBuses('');
    _startUserLocation();
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ticker?.cancel();
    _liveSub?.cancel();
    _userSub?.cancel();
    _vehicleAnimator.removeListener(_onVehicleAnimated);
    _vehicleAnimator.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------- list / search ----------

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _searchBuses(q));
  }

  Future<void> _searchBuses(String q) async {
    final token = ++_token;
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final rows = await SupabaseService.getAssignedBuses(query: q, limit: 30);
      if (!mounted || token != _token) return;
      setState(() => _buses = rows);

      if (_selected == null && rows.isNotEmpty) {
        String? targetBusId = widget.initialBusId;
        if (targetBusId == null) {
          final profile = await SupabaseService.getMyProfile();
          targetBusId = profile?['default_bus_id'];
        }
        Map<String, dynamic> match = {};
        if (targetBusId != null) {
          match = rows.firstWhere(
            (b) => '${b['busId']}' == targetBusId,
            orElse: () => <String, dynamic>{},
          );
        }
        if (match.isEmpty) {
          match = rows.firstWhere(
            (b) => b['status'] == 'running',
            orElse: () => rows.first,
          );
        }
        if (mounted && match.isNotEmpty) {
          _followBus(match);
        }
      }
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() => _listError = 'Could not load buses. Check connection.');
    } finally {
      if (mounted && token == _token) setState(() => _loadingList = false);
    }
  }

  // ---------- user location ----------

  Future<void> _startUserLocation() async {
    try {
      var permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (permission != PermissionStatus.granted && permission != PermissionStatus.grantedLimited) return;

      _userSub = _location.onLocationChanged.listen((d) {
        if (d.latitude == null || d.longitude == null || !mounted) return;
        setState(() {
          _userLocation = LatLng(d.latitude!, d.longitude!);
        });
      });
    } catch (e) {
      debugPrint('user location unavailable: $e');
    }
  }

  // ---------- follow bus ----------

  void _followBus(Map<String, dynamic> bus) {
    _liveSub?.cancel();
    _vehicleAnimator.reset();
    setState(() {
      _selected = bus;
      _lastUpdate = null;
      _liveStatus = bus['status'] ?? 'idle';
      _currentSpeedMps = null;
      _nextStopName = null;
      _etaString = null;
      _showBusListOverlay = false;
      _autoFollow = true;
      _markers.clear();
      _polylines.clear();
      _roadPoints.clear();
      _roadDistanceMeters = null;
      _roadDurationSeconds = null;
      _lastRoutedBusPos = null;
      _hasFiredProximityAlert = false;
      _showProximityBanner = false;
      _dismissedIssueBanner = false;
    });

    final busId = bus['busId'] as String?;
    if (busId != null) {
      _liveSub = SupabaseService.streamBusLive(busId).listen(_onLive, onError: (e) {
        debugPrint('live stream error: $e');
      });
      // Immediate REST fetch so UI shows location without waiting for websocket
      SupabaseService.getBusLive(busId).then((live) {
        if (mounted && _selected != null && _selected!['busId'] == busId && live != null) {
          _onLive(live);
        }
      });
    }
    final routeId = bus['routeId'] as String?;
    if (routeId != null && routeId.isNotEmpty) {
      _drawRoute(routeId);
    }
  }

  void _onLive(Map<String, dynamic>? row) {
    if (!mounted) return;
    final status = '${row?['status'] ?? 'idle'}';
    final lat = (row?['latitude'] as num?)?.toDouble();
    final lng = (row?['longitude'] as num?)?.toDouble();
    final speed = (row?['speed_mps'] as num?)?.toDouble();
    final heading = (row?['heading'] as num?)?.toDouble();
    final updated = DateTime.tryParse('${row?['updated_at'] ?? ''}')?.toLocal();

    final isLiveStatus = status == 'running' || status == 'delayed' || status == 'traffic_jam' || status == 'breakdown';

    setState(() {
      _liveStatus = status;
      _lastUpdate = updated;
      _currentSpeedMps = speed;

      // Speed and ETA calculation
      final kmh = ((speed ?? 8.33) * 3.6).round();
      final safeSpeed = kmh > 0 ? kmh : 25;
      _etaString = 'ETA ~${(8 / (safeSpeed / 60)).round().clamp(2, 45)} min';
    });

    if (lat != null && lng != null && isLiveStatus) {
      final newPos = LatLng(lat, lng);
      // Validate GPS update before feeding into smooth animator
      if (TrackingInterpolator.isValidGpsUpdate(
        latitude: lat,
        longitude: lng,
        accuracy: null,
        timestamp: updated ?? DateTime.now(),
      )) {
        _vehicleAnimator.updateTarget(
          newPosition: newPos,
          reportedHeading: heading,
          speedMps: speed,
          timestamp: updated,
        );
        _checkGeofenceProximity(newPos);
      }
    } else {
      // Trip is not running or coordinates are empty: remove bus marker and dynamic polyline
      setState(() {
        _markers.removeWhere((m) => m.key == const Key('busLocation'));
        _rebuildDynamicPolyline();
      });
    }
  }

  void _checkGeofenceProximity(LatLng busPos) {
    if (_hasFiredProximityAlert || _targetStopLatLng == null) return;
    final dist = OsrmRoutingService.calculateHaversineDistance(busPos, _targetStopLatLng!);
    if (dist <= 500.0) {
      _hasFiredProximityAlert = true;
      try {
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _showProximityBanner = true;
        });
      }
    }
  }

  Future<void> _updateRoadRouting({bool force = false}) async {
    if (_isRouting || _destinationLatLng == null) return;
    final busPos = _vehicleAnimator.currentPosition;
    if (busPos == null) return;

    if (!force && _lastRoutedBusPos != null) {
      final drift = OsrmRoutingService.calculateHaversineDistance(busPos, _lastRoutedBusPos!);
      if (drift < 60.0) {
        final directDist = OsrmRoutingService.calculateHaversineDistance(busPos, _destinationLatLng!);
        if (_roadDistanceMeters != null && _roadDistanceMeters! > directDist) {
          _roadDistanceMeters = directDist;
          _roadDurationSeconds = directDist / 6.94;
          if (mounted) setState(() {});
        }
        return;
      }
    }

    _isRouting = true;
    try {
      final res = await OsrmRoutingService.fetchRoadRoute(busPos, _destinationLatLng!);
      if (mounted) {
        setState(() {
          _roadPoints = res.polylinePoints;
          _roadDistanceMeters = res.distanceMeters;
          _roadDurationSeconds = res.durationSeconds;
          _isRoadGeometry = res.isRoadGeometry;
          _lastRoutedBusPos = busPos;
          _rebuildDynamicPolyline();
        });
      }
    } catch (e) {
      debugPrint('Student road routing error: $e');
    } finally {
      _isRouting = false;
    }
  }

  void _rebuildDynamicPolyline() {
    _polylines.clear();
    final busPos = _vehicleAnimator.currentPosition;
    final isLive = _liveStatus == 'running' || _liveStatus == 'delayed' || _liveStatus == 'traffic_jam' || _liveStatus == 'breakdown';
    if (isLive && busPos != null && _destinationLatLng != null) {
      final points = _roadPoints.isNotEmpty ? _roadPoints : [busPos, _destinationLatLng!];
      _polylines.add(
        Polyline(
          points: points,
          color: AppTheme.liveMarker,
          strokeWidth: 4.5,
          borderColor: const Color(0x4DF59E0B),
          borderStrokeWidth: 1.5,
        ),
      );
    }
  }

  void _centerRouteCamera() {
    final busPos = _vehicleAnimator.currentPosition;
    if (busPos != null && _destinationLatLng != null) {
      final bounds = LatLngBounds.fromPoints([busPos, _destinationLatLng!]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } else if (busPos != null) {
      _mapController.move(busPos, 14.5);
    }
  }

  void _onVehicleAnimated() {
    if (!mounted) return;
    final pos = _vehicleAnimator.currentPosition;
    if (pos == null) return;

    final isLive = _liveStatus == 'running' || _liveStatus == 'delayed' || _liveStatus == 'traffic_jam' || _liveStatus == 'breakdown';

    setState(() {
      _markers.removeWhere((m) => m.key == const Key('busLocation'));
      if (isLive) {
        _markers.add(_buildAnimatedBusMarker(pos, _vehicleAnimator.currentHeading, isLive: true));
      }
      _rebuildDynamicPolyline();
    });

    if (isLive) {
      _checkGeofenceProximity(pos);
      _updateRoadRouting();
    }

    // Smooth auto-follow without hard-resetting user's zoom!
    if (_autoFollow && isLive) {
      _mapController.move(pos, _mapController.camera.zoom);
    }
  }

  Marker _buildAnimatedBusMarker(LatLng pos, double heading, {bool isLive = true}) {
    final rad = heading * (math.pi / 180.0);
    final busCode = (_selected?['busNumber'] ?? 'BUS').toString();
    final isIssue = _liveStatus == 'breakdown' || _liveStatus == 'traffic_jam' || _liveStatus == 'delayed';
    final vehicleColor = isIssue
        ? AppTheme.error
        : isLive
            ? AppTheme.liveMarker
            : const Color(0xFF64748B);
    final badgeText = isIssue
        ? '⚠️ $busCode'
        : isLive
            ? busCode
            : '$busCode (Idle)';

    return Marker(
      key: const Key('busLocation'),
      point: pos,
      width: 76,
      height: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.rotate(
            angle: rad,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Halo Ring with Breathing Effect when live
                if (isLive)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: vehicleColor.withOpacity(0.24),
                      shape: BoxShape.circle,
                    ),
                  ),
                // Vehicle Body matching Figma System 1.0 (Amber #F59E0B or Red SOS rounded 12px)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: vehicleColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isIssue ? Icons.warning_rounded : Icons.directions_bus_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                // Forward Directional Indicator (Points in direction of travel)
                if (isLive)
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_drop_up_rounded,
                        color: isIssue ? AppTheme.error : AppTheme.primaryColor,
                        size: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isIssue ? AppTheme.error : isLive ? AppTheme.liveMarker : const Color(0xFFCBD5E1),
                width: isLive ? 1.5 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x25000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isIssue ? AppTheme.error : isLive ? AppTheme.text : AppTheme.muted,
                letterSpacing: 0.2,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _drawRoute(String routeId) async {
    try {
      final stops = await SupabaseService.getStopsForRoute(routeId);
      final points = <LatLng>[];
      final stopMarkers = <Marker>[];

      for (int i = 0; i < stops.length; i++) {
        final s = stops[i];
        final p = LatLng((s['latitude'] as num).toDouble(), (s['longitude'] as num).toDouble());
        points.add(p);
        final seq = s['sequence_no'] ?? (i + 1);

        if (i == 0 && _nextStopName == null) {
          _nextStopName = s['name'] ?? 'College Campus';
        }

        // Figma Stop Marker (26x26 circular, white fill, 2px blue border, bold blue sequence)
        stopMarkers.add(Marker(
          key: Key('stop_${s['id']}'),
          point: p,
          width: 80,
          height: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F0F172A), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$seq',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.muted,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${s['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ));
      }

      if (points.isNotEmpty) {
        _destinationLatLng = points.last;
        _destinationName = stops.last['name']?.toString() ?? 'Campus Terminal';

        // Select target stop for 500m geofence proximity alerts
        if (_userLocation != null) {
          double minDistance = double.infinity;
          int bestIndex = 0;
          for (int i = 0; i < points.length; i++) {
            final d = OsrmRoutingService.calculateHaversineDistance(_userLocation!, points[i]);
            if (d < minDistance) {
              minDistance = d;
              bestIndex = i;
            }
          }
          _targetStopLatLng = points[bestIndex];
          _targetStopName = stops[bestIndex]['name']?.toString() ?? 'Your Stop';
        } else {
          _targetStopLatLng = points.first;
          _targetStopName = stops.first['name']?.toString() ?? 'Boarding Stop';
        }
        _updateRoadRouting(force: true);
      }

      if (!mounted || points.isEmpty) return;
      setState(() {
        _markers.addAll(stopMarkers);
        // Note: Static blue polyline is completely removed.
        _rebuildDynamicPolyline();
      });

      if (_liveStatus != 'running') {
        _mapController.move(points.first, 14.0);
      }
    } catch (e) {
      debugPrint('route draw failed: $e');
    }
  }

  (String, StatusChipType, Color, Color) _statusDetails() {
    if (_selected == null) return ('Select a bus', StatusChipType.select, AppTheme.infoBg, AppTheme.info);
    if (_liveStatus == 'breakdown') {
      return ('Breakdown Reported', StatusChipType.offline, const Color(0xFFFEE2E2), AppTheme.error);
    }
    if (_liveStatus == 'traffic_jam') {
      return ('Traffic Delay', StatusChipType.delayed, const Color(0xFFFEF3C7), const Color(0xFFB45309));
    }
    if (_liveStatus == 'delayed') {
      return ('Route Diverted', StatusChipType.delayed, const Color(0xFFFEF3C7), const Color(0xFFB45309));
    }
    if (_liveStatus != 'running') return ('Trip not started yet', StatusChipType.taken, AppTheme.surfaceSubtle, AppTheme.muted);
    final u = _lastUpdate;
    if (u == null) return ('Waiting for GPS signal...', StatusChipType.delayed, AppTheme.warningBg, AppTheme.warning);

    final freshness = TrackingInterpolator.getTelemetryState(u);
    final secs = DateTime.now().difference(u).inSeconds;

    switch (freshness) {
      case TelemetryFreshness.live:
        final motionLabel = _vehicleAnimator.isStationary ? 'LIVE · At Stop' : 'LIVE';
        return (motionLabel, StatusChipType.live, AppTheme.successBg, AppTheme.success);
      case TelemetryFreshness.delayed:
        return ('Signal Delayed (${secs}s)', StatusChipType.delayed, AppTheme.warningBg, AppTheme.warning);
      case TelemetryFreshness.lost:
        return ('Signal Lost (${(secs / 60).floor()}m)', StatusChipType.offline, AppTheme.errorBg, AppTheme.error);
    }
  }

  void _recenter() {
    final pos = _vehicleAnimator.currentPosition;
    final isLiveMotion = _liveStatus == 'running' || _liveStatus == 'delayed' || _liveStatus == 'traffic_jam' || _liveStatus == 'breakdown';
    if (pos != null && isLiveMotion) {
      _mapController.move(pos, _mapController.camera.zoom);
    } else if (_markers.any((m) => m.key == const Key('busLocation'))) {
      final busMarker = _markers.firstWhere((m) => m.key == const Key('busLocation'));
      _mapController.move(busMarker.point, _mapController.camera.zoom);
    } else if (_userLocation != null) {
      _mapController.move(_userLocation!, 15.0);
    } else {
      _mapController.move(_kFallbackCenter, 14.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, chipType, statusBg, statusFg) = _statusDetails();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Fleet',
            onPressed: () {
              SupabaseService.invalidateCaches();
              _searchBuses(_searchController.text);
            },
          ),
          IconButton(
            icon: Icon(_showBusListOverlay ? Icons.map_rounded : Icons.view_list_rounded),
            tooltip: _showBusListOverlay ? 'Show Map' : 'Bus Fleet',
            onPressed: () {
              setState(() => _showBusListOverlay = !_showBusListOverlay);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full-bleed OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kFallbackCenter,
              initialZoom: 14.5,
              onPositionChanged: (camera, hasGesture) {
                // If user drags/zooms map manually, pause auto-follow
                if (hasGesture && _autoFollow) {
                  setState(() => _autoFollow = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cbts.transport',
              ),
              if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
              MarkerLayer(
                markers: [
                  ..._markers,
                  // Figma User Location Marker (Blue Dot + Accuracy Ring + "You" Label)
                  if (_userLocation != null)
                    Marker(
                      key: const Key('userLocation'),
                      point: _userLocation!,
                      width: 50,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.info.withOpacity(0.20),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: AppTheme.info,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.info,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Floating Top Header: Search & Bus Status
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input matching Figma S05 · Fields & Search
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _onSearchChanged(val);
                      if (!_showBusListOverlay) {
                        setState(() => _showBusListOverlay = true);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search bus number or route...',
                      hintStyle: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.muted, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppTheme.muted, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _searchBuses('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Selected Bus Status Banner matching Figma S10 · StudentTrackingStatus
                if (_selected != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F0F172A),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_bus_rounded, color: statusFg, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bus ${_selected!['busNumber']}  ·  ${_selected!['numberPlate'] ?? ''}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: statusFg,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        StatusChip(
                          label: statusLabel,
                          type: chipType,
                        ),
                      ],
                    ),
                  ),

                // Urgent Breakdown / Delay Alert Banner (Task 4)
                if ((_liveStatus == 'breakdown' || _liveStatus == 'traffic_jam' || _liveStatus == 'delayed') && !_dismissedIssueBanner) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF87171)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F0F172A), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ Bus Delayed: ${_liveStatus == 'breakdown' ? 'Mechanical Breakdown' : _liveStatus == 'traffic_jam' ? 'Severe Traffic Jam' : 'Route Diversion'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.error,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const Text(
                                'College transport management has been notified.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontFamily: 'Inter'),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.error),
                          onPressed: () => setState(() => _dismissedIssueBanner = true),
                        ),
                      ],
                    ),
                  ),
                ],

                // 500m Stop Proximity Geofence Alert Banner (Task 3)
                if (_showProximityBanner) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBBF24)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F0F172A), blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🔔 Bus ${_selected?['busNumber'] ?? ''} is 500m from your stop!',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Text(
                                'Approx. 2 minutes away at ${_targetStopName ?? 'your stop'}. Please proceed to boarding point.',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontFamily: 'Inter'),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _showProximityBanner = false);
                            _centerRouteCamera();
                          },
                          child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFF92400E)),
                          onPressed: () => setState(() => _showProximityBanner = false),
                        ),
                      ],
                    ),
                  ),
                ],

                // Live Distance & ETA HUD (Task 2)
                if (_selected != null &&
                    (_liveStatus == 'running' || _liveStatus == 'delayed' || _liveStatus == 'traffic_jam' || _liveStatus == 'breakdown') &&
                    _roadDistanceMeters != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: LiveEtaHud(
                      destinationName: _destinationName ?? 'Campus Terminal',
                      distanceText: OsrmRoutingService.formatDistance(_roadDistanceMeters!),
                      etaText: OsrmRoutingService.formatEta(_roadDurationSeconds ?? 0),
                      onTap: _centerRouteCamera,
                      accentColor: AppTheme.liveMarker,
                      isRoadRoute: _isRoadGeometry,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Floating Recenter Map Button (Figma 48px square rounded 12px)
          Positioned(
            right: 16,
            bottom: _selected != null ? 140 : 24,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: _autoFollow
                    ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5)
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F172A),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  _autoFollow ? Icons.gps_fixed_rounded : Icons.my_location_rounded,
                  color: _autoFollow ? AppTheme.primaryColor : AppTheme.text,
                  size: 24,
                ),
                tooltip: _autoFollow ? 'Following Bus (Tap to Unpin)' : 'Recenter & Follow Bus',
                onPressed: () {
                  setState(() => _autoFollow = true);
                  _recenter();
                },
              ),
            ),
          ),

          // 4. Floating Student Arrival Sheet matching Figma StudentArrivalSheet (7:1756)
          if (_selected != null && !_showBusListOverlay)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F0F172A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sheet Handle (40x4, rounded 2px)
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Destination / Next Stop Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _destinationName != null ? 'To: $_destinationName' : 'Next stop',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.muted,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          _nextStopName ?? 'Campus Terminal',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Arrival ETA and Speed Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _liveStatus == 'running'
                              ? (_etaString ?? 'ETA 5 min')
                              : 'Trip Not Started',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          _liveStatus == 'running' && _currentSpeedMps != null
                              ? 'Speed  ${(_currentSpeedMps! * 3.6).round()} km/h'
                              : 'In Depot',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: AppTheme.muted,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    if (_liveStatus != 'running')
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Driver / Faculty-Incharge has not started this trip yet. Live GPS tracking will activate here automatically once the trip begins.',
                          style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 5. Bus Search / Fleet Overlay List matching Figma DriverBusResult / StudentBusMatch
          if (_showBusListOverlay)
            Positioned.fill(
              top: 110,
              child: Container(
                color: AppTheme.background,
                child: Column(
                  children: [
                    if (_loadingList)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: AppTheme.surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_buses.length} buses found',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.muted,
                              fontFamily: 'Inter',
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _showBusListOverlay = false),
                            child: const Text('Back to Map', style: TextStyle(color: AppTheme.primaryColor)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _listError != null
                          ? Center(child: Text(_listError!, style: const TextStyle(color: AppTheme.error)))
                          : (_buses.isEmpty && !_loadingList)
                              ? const Center(
                                  child: Text(
                                    'No bus found. Check the number.',
                                    style: TextStyle(color: AppTheme.muted, fontFamily: 'Inter'),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: _buses.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final b = _buses[i];
                                    final isRunning = b['status'] == 'running';
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A0F172A),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isRunning ? AppTheme.primarySubtle : AppTheme.surfaceSubtle,
                                              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                            ),
                                            child: Icon(
                                              Icons.directions_bus_rounded,
                                              color: isRunning ? AppTheme.primaryColor : AppTheme.muted,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Bus ${b['busNumber']}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.text,
                                                    fontFamily: 'Inter',
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${b['numberPlate'] ?? ''}  ·  ${b['routeName'] ?? 'Direct Route'}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.muted,
                                                    fontFamily: 'Inter',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 80,
                                            height: 42,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryColor,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                                ),
                                              ),
                                              onPressed: () => _followBus(b),
                                              child: const Text(
                                                'Track',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  fontFamily: 'Inter',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
