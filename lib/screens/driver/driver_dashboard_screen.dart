import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_service.dart';
import '../../services/gps_tracking_service.dart';
import '../../services/tracking_interpolator.dart';
import '../../services/osm_geocoding_service.dart';
import '../../services/osrm_routing_service.dart';
import '../../widgets/live_eta_hud.dart';
import '../../supabase_config.dart';
import '../../shared/theme.dart';
import '../../shared/status_chip.dart';
import 'driver_profile_screen.dart';
import 'driver_view_feedback_screen.dart';
import 'driver_route_overview_screen.dart';

/// Default College Campus Center (AITAM Tekkali)
const LatLng _kFallbackCenter = LatLng(SupabaseConfig.defaultCampusLat, SupabaseConfig.defaultCampusLng);

/// Driver Dashboard matching Figma 12 · Trip running (2:1679)
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>?> _assignmentFuture;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    _assignmentFuture = SupabaseService.getDriverAssignment();
  }

  void _reload() {
    setState(() {
      _redirected = false;
      _assignmentFuture = SupabaseService.getDriverAssignment();
    });
  }

  Future<void> _logout() async {
    await GpsTrackingService.stopTracking();
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/driver_login', (_) => false);
    }
  }

  Future<void> _changeBus() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: const Text('Change bus?', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: const Text(
          'This ends your current trip and frees this bus for another driver.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await GpsTrackingService.stopTracking();
    try {
      await SupabaseService.releaseBus();
    } catch (_) {}
    if (mounted) Navigator.pushReplacementNamed(context, '/driver_select_bus');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _assignmentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              title: const Text('Driver / Faculty-Incharge console'),
              backgroundColor: AppTheme.surface,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.error),
                    const SizedBox(height: 12),
                    const Text('Could not load your bus assignment.', style: TextStyle(fontSize: 16, fontFamily: 'Inter')),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                    TextButton(onPressed: _logout, child: const Text('Logout', style: TextStyle(color: AppTheme.muted))),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          if (!_redirected) {
            _redirected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pushReplacementNamed(context, '/driver_select_bus');
            });
          }
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          );
        }

        final busNumber = '${data['busNumber'] ?? ''}';
        final routeName = '${data['routeName'] ?? 'Route not set'}';
        final routeId = '${data['routeId'] ?? ''}';
        final busId = '${data['busId'] ?? ''}';

        final pages = <Widget>[
          DriverHomePageContent(
            key: const PageStorageKey('DriverHomePageContent'),
            busNumber: busNumber,
            routeName: routeName,
            routeId: routeId,
            busId: busId,
          ),
          DriverRouteOverviewScreen(
            driverEmail: SupabaseService.currentEmail ?? '',
            busNumber: busNumber,
            routeName: routeName,
            busId: busId,
            routeId: routeId,
          ),
          const DriverProfileScreen(),
          const DriverViewFeedbackScreen(),
        ];

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Driver / Faculty-Incharge console'),
            backgroundColor: AppTheme.surface,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: _changeBus,
                tooltip: 'Change bus',
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: IndexedStack(index: _selectedIndex, children: pages),
          // Figma DriverBottomNavigation (2:3576)
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.directions_bus_rounded, 'Console'),
                _buildNavItem(1, Icons.alt_route_rounded, 'Route'),
                _buildNavItem(2, Icons.person_rounded, 'Profile'),
                _buildNavItem(3, Icons.feedback_outlined, 'Feedback'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppTheme.primaryColor : AppTheme.muted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : AppTheme.muted,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverHomePageContent extends StatefulWidget {
  final String busNumber;
  final String routeName;
  final String routeId;
  final String busId;

  const DriverHomePageContent({
    required this.busNumber,
    required this.routeName,
    required this.routeId,
    required this.busId,
    super.key,
  });

  @override
  State<DriverHomePageContent> createState() => _DriverHomePageContentState();
}

class _DriverHomePageContentState extends State<DriverHomePageContent> with TickerProviderStateMixin {
  bool _isTracking = false;
  bool _busy = false;
  bool _gpsError = false;
  Position? _currentLocation;
  final MapController _mapController = MapController();
  final List<Polyline> _polylines = [];
  final List<Marker> _markers = [];
  LatLng? _routeStart;

  late final LiveVehicleAnimator _vehicleAnimator;

  // Dynamic Location Picker & Destination
  OsmLocation? _selectedDestination;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<OsmLocation> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  bool _showSearchResults = false;

  // Road-Curved OSRM Routing & Dynamic ETA HUD
  List<LatLng> _roadPoints = [];
  double? _roadDistanceMeters;
  double? _roadDurationSeconds;
  bool _isRoadGeometry = false;
  LatLng? _lastRoutedStart;
  bool _isRouting = false;
  String? _activeReportedIssue;

  @override
  void initState() {
    super.initState();
    _vehicleAnimator = LiveVehicleAnimator(vsync: this);
    _vehicleAnimator.addListener(_onDriverVehicleAnimated);
    _loadRouteStops();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _vehicleAnimator.removeListener(_onDriverVehicleAnimated);
    _vehicleAnimator.dispose();
    super.dispose();
  }

  Marker _buildDriverBusMarker(LatLng pos, double heading) {
    return Marker(
      key: const ValueKey('driverLocation'),
      point: pos,
      width: 64,
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.rotate(
            angle: heading * (math.pi / 180.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.liveMarker,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_drop_up_rounded, color: AppTheme.primaryColor, size: 8),
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
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0x25000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            child: Text(
              widget.busNumber.isNotEmpty ? widget.busNumber : 'BUS',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
                letterSpacing: 0.2,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDriverVehicleAnimated() {
    if (!mounted) return;
    final pos = _vehicleAnimator.currentPosition;
    if (pos == null) return;

    setState(() {
      _markers.removeWhere((m) => m.key == const ValueKey('driverLocation'));
      _markers.add(_buildDriverBusMarker(pos, _vehicleAnimator.currentHeading));
      _rebuildDynamicPolylines();
    });
    _mapController.move(pos, _mapController.camera.zoom);

    if (_selectedDestination != null) {
      _updateRoadRouting();
    }
  }

  Future<void> _updateRoadRouting({bool force = false}) async {
    if (_selectedDestination == null || _isRouting) return;
    final startPos = _vehicleAnimator.currentPosition ??
        (_currentLocation != null ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude) : _routeStart);
    if (startPos == null) return;
    final destPos = LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude);

    if (!force && _lastRoutedStart != null) {
      final drift = OsrmRoutingService.calculateHaversineDistance(startPos, _lastRoutedStart!);
      if (drift < 50.0) {
        final directDist = OsrmRoutingService.calculateHaversineDistance(startPos, destPos);
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
      final res = await OsrmRoutingService.fetchRoadRoute(startPos, destPos);
      if (mounted) {
        setState(() {
          _roadPoints = res.polylinePoints;
          _roadDistanceMeters = res.distanceMeters;
          _roadDurationSeconds = res.durationSeconds;
          _isRoadGeometry = res.isRoadGeometry;
          _lastRoutedStart = startPos;
          _rebuildDynamicPolylines();
        });
      }
    } catch (e) {
      debugPrint('Road routing calculation error: $e');
    } finally {
      _isRouting = false;
    }
  }

  void _rebuildDynamicPolylines() {
    _polylines.clear();
    if (_selectedDestination == null) return;

    final startPos = _vehicleAnimator.currentPosition ??
        (_currentLocation != null ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude) : _routeStart);

    if (startPos != null) {
      final destPos = LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude);
      final points = _roadPoints.isNotEmpty ? _roadPoints : [startPos, destPos];

      _polylines.add(
        Polyline(
          points: points,
          color: AppTheme.primaryColor,
          strokeWidth: 4.5,
          borderColor: const Color(0x4D800000),
          borderStrokeWidth: 1.5,
        ),
      );
    }
  }

  void _centerRouteCamera() {
    if (_selectedDestination == null) return;
    final startPos = _vehicleAnimator.currentPosition ??
        (_currentLocation != null ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude) : _routeStart);
    final destPos = LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude);
    if (startPos != null) {
      final bounds = LatLngBounds.fromPoints([startPos, destPos]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    } else {
      _mapController.move(destPos, 14.5);
    }
  }

  void _showReportIssueSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Trip Issue / SOS',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                              fontFamily: 'Inter',
                            ),
                          ),
                          Text(
                            'Instantly alerts students & transport dispatch',
                            style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildIssueOption(
                  icon: Icons.car_crash_rounded,
                  color: AppTheme.error,
                  title: 'Mechanical Breakdown',
                  subtitle: 'Engine breakdown, tire puncture, or mechanical failure',
                  onTap: () => _confirmAndReportIssue('breakdown', 'Mechanical Breakdown'),
                ),
                const SizedBox(height: 8),
                _buildIssueOption(
                  icon: Icons.traffic_rounded,
                  color: Colors.orange.shade800,
                  title: 'Severe Traffic Jam',
                  subtitle: 'Heavy gridlock or accident road block (>15m delay)',
                  onTap: () => _confirmAndReportIssue('traffic_jam', 'Severe Traffic Jam'),
                ),
                const SizedBox(height: 8),
                _buildIssueOption(
                  icon: Icons.alt_route_rounded,
                  color: Colors.amber.shade900,
                  title: 'Route Diversion / Blocked',
                  subtitle: 'Road repair or detour in effect',
                  onTap: () => _confirmAndReportIssue('delayed', 'Route Diversion / Delay'),
                ),
                if (_activeReportedIssue != null && _activeReportedIssue != 'running') ...[
                  const SizedBox(height: 8),
                  _buildIssueOption(
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.success,
                    title: 'Resolve & Resume Normal Trip',
                    subtitle: 'Issue cleared, proceeding on scheduled route',
                    onTap: () => _confirmAndReportIssue('running', 'Standard Service Resumed'),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssueOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndReportIssue(String issueType, String label) async {
    try {
      await SupabaseService.reportTripIssue(
        busId: widget.busId,
        issueType: issueType,
        busCode: widget.busNumber,
      );
      if (mounted) {
        setState(() => _activeReportedIssue = issueType);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(issueType == 'running'
                ? 'Trip status resumed to normal.'
                : 'Urgent Alert Broadcast: $label sent to students & dispatch!'),
            backgroundColor: issueType == 'running' ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to broadcast alert: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Marker _buildDestinationMarker(OsmLocation loc) {
    return Marker(
      key: const ValueKey('destination_pin'),
      point: LatLng(loc.latitude, loc.longitude),
      width: 140,
      height: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              loc.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Icon(
            Icons.location_on_rounded,
            color: AppTheme.primaryColor,
            size: 28,
          ),
        ],
      ),
    );
  }

  Future<void> _onMapTapped(LatLng point) async {
    _searchFocus.unfocus();
    setState(() => _showSearchResults = false);

    final tempName = 'Pin (${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)})';
    _setDestination(
      OsmLocation(
        id: 'pin_${point.latitude}_${point.longitude}',
        name: tempName,
        displayName: tempName,
        latitude: point.latitude,
        longitude: point.longitude,
        source: 'osm_nominatim',
      ),
      isOptimistic: true,
    );

    final address = await OsmGeocodingService.reverseGeocode(point.latitude, point.longitude);
    if (mounted && address != null) {
      final parts = address.split(',');
      final shortName = parts.isNotEmpty ? parts.first.trim() : address;
      _setDestination(
        OsmLocation(
          id: 'pin_${point.latitude}_${point.longitude}',
          name: shortName,
          displayName: address,
          latitude: point.latitude,
          longitude: point.longitude,
          source: 'osm_nominatim',
        ),
      );
      _toast('Destination set: $shortName');
    }
  }

  void _setDestination(OsmLocation destination, {bool isOptimistic = false}) {
    setState(() {
      _selectedDestination = destination;
      _searchController.text = destination.name;
      _showSearchResults = false;

      _markers.removeWhere((m) => m.key == const ValueKey('destination_pin'));
      _markers.add(_buildDestinationMarker(destination));

      _rebuildDynamicPolylines();
    });

    final destLatLng = LatLng(destination.latitude, destination.longitude);
    _mapController.move(destLatLng, 14.5);
    _updateRoadRouting(force: true);

    if (_isTracking && !isOptimistic) {
      SupabaseService.setTripDestination(destination.name);
    }
  }

  void _clearDestination() {
    setState(() {
      _selectedDestination = null;
      _searchController.clear();
      _showSearchResults = false;
      _roadPoints.clear();
      _roadDistanceMeters = null;
      _roadDurationSeconds = null;
      _lastRoutedStart = null;
      _markers.removeWhere((m) => m.key == const ValueKey('destination_pin'));
      _rebuildDynamicPolylines();
    });
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await OsmGeocodingService.searchLocations(q);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _loadRouteStops() async {
    if (widget.routeId.isEmpty) return;
    try {
      final stops = await SupabaseService.getStopsForRoute(widget.routeId);
      final coords = <LatLng>[];
      final markers = <Marker>[];
      for (int i = 0; i < stops.length; i++) {
        final stop = stops[i];
        final pos = LatLng((stop['latitude'] as num).toDouble(), (stop['longitude'] as num).toDouble());
        coords.add(pos);
        final seq = stop['sequence_no'] ?? (i + 1);

        markers.add(Marker(
          key: ValueKey('stop_${stop['id']}'),
          point: pos,
          width: 28,
          height: 28,
          child: Container(
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
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.muted,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ));
      }
      if (!mounted || coords.isEmpty) return;

      setState(() {
        _routeStart = coords.first;
        _markers.removeWhere((m) => m.key != const ValueKey('driverLocation') && m.key != const ValueKey('destination_pin'));
        _markers.addAll(markers);
        // Note: Static blue polyline is completely removed.
        _rebuildDynamicPolylines();
      });
      _mapController.move(coords.first, 13.5);
    } catch (e) {
      debugPrint('load stops failed: $e');
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _refreshGpsLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      if (!mounted) return;
      _currentLocation = pos;
      final latLng = LatLng(pos.latitude, pos.longitude);
      _vehicleAnimator.updateTarget(
        newPosition: latLng,
        reportedHeading: pos.heading,
        speedMps: pos.speed,
        timestamp: pos.timestamp,
      );
      _mapController.move(latLng, 15.0);
      if (_isTracking) {
        await SupabaseService.postLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          speed: pos.speed,
          heading: pos.heading,
        );
        _toast('GPS locked & live location broadcasted!');
      } else {
        _toast('GPS locked to current position.');
      }
    } catch (e) {
      if (_currentLocation != null) {
        _mapController.move(LatLng(_currentLocation!.latitude, _currentLocation!.longitude), 15.0);
      } else if (_routeStart != null) {
        _mapController.move(_routeStart!, 14.0);
      }
      _toast('Acquiring GPS fix...', error: false);
    }
  }

  Future<void> _startTracking() async {
    setState(() => _busy = true);
    try {
      Position? initialFix;
      try {
        initialFix = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
      } catch (_) {
        initialFix = await Geolocator.getLastKnownPosition();
      }

      await SupabaseService.startTrip();

      // Immediately post coordinates and update marker so it never lags
      if (initialFix != null) {
        final fixLatLng = LatLng(initialFix.latitude, initialFix.longitude);
        _currentLocation = initialFix;
        _vehicleAnimator.updateTarget(
          newPosition: fixLatLng,
          reportedHeading: initialFix.heading,
          speedMps: initialFix.speed,
          timestamp: initialFix.timestamp,
        );
        try {
          await SupabaseService.postLocation(
            latitude: initialFix.latitude,
            longitude: initialFix.longitude,
            speed: initialFix.speed,
            heading: initialFix.heading,
          );
        } catch (e) {
          debugPrint('Initial postLocation failed: $e');
        }
      }

      final ok = await GpsTrackingService.startTracking(
        onLocationUpdate: (pos) {
          if (!mounted) return;
          _currentLocation = pos;
          _vehicleAnimator.updateTarget(
            newPosition: LatLng(pos.latitude, pos.longitude),
            reportedHeading: pos.heading,
            speedMps: pos.speed,
            timestamp: pos.timestamp,
          );
        },
        onError: (_) {
          if (mounted && !_gpsError) setState(() => _gpsError = true);
        },
      );

      if (!ok) {
        await SupabaseService.endTrip();
        _toast('Could not start tracking. Turn on GPS and allow location permission.', error: true);
        return;
      }
      if (mounted) setState(() => _isTracking = true);
      if (_selectedDestination != null) {
        SupabaseService.setTripDestination(_selectedDestination!.name);
      }
      _toast('Trip started! Students can now track your bus in real time.');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopTracking() async {
    setState(() => _busy = true);
    try {
      await GpsTrackingService.stopTracking();
      _vehicleAnimator.reset();
      await SupabaseService.endTrip();
      if (mounted) {
        setState(() {
          _isTracking = false;
          _gpsError = false;
          _currentLocation = null;
          _markers.removeWhere((m) => m.key == const ValueKey('driverLocation'));
        });
      }
      _toast('Trip ended. Location sharing stopped.');
    } catch (e) {
      _toast('Could not end trip: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentLocation != null
        ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
        : (_routeStart ?? _kFallbackCenter);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Driver / Faculty-Incharge Identity and Bus/Route Chips matching Figma 2:4335
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Driver / Faculty-Incharge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  SupabaseService.currentEmail ?? 'driver@college.ac.in',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.muted,
                    fontFamily: 'Inter',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                ),
                child: Text(
                  'Bus ${widget.busNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  ),
                  child: Text(
                    widget.routeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Persistent Sharing Status Banner matching Figma 2:4342
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isTracking
                  ? (_gpsError ? AppTheme.warningBg : AppTheme.successBg)
                  : AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
            child: Row(
              children: [
                StatusChip(
                  type: _isTracking
                      ? (_gpsError ? StatusChipType.delayed : StatusChipType.live)
                      : StatusChipType.taken,
                  label: _isTracking
                      ? (_gpsError ? 'Network issue' : 'LIVE')
                      : 'Standby',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isTracking
                        ? (_gpsError ? 'GPS retrying connection...' : 'Sharing live location')
                        : 'Trip stopped · Not sharing location',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isTracking
                          ? (_gpsError ? AppTheme.warning : AppTheme.success)
                          : AppTheme.muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 56px Trip Action Controls matching Figma DriverTripAction (2:3569 / 2:3571)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (!_isTracking && !_busy) ? AppTheme.success : AppTheme.surfaceSubtle,
                      foregroundColor: (!_isTracking && !_busy) ? Colors.white : AppTheme.muted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      ),
                    ),
                    onPressed: (_isTracking || _busy) ? null : _startTracking,
                    child: const Text(
                      'Start Trip',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_isTracking && !_busy) ? AppTheme.error : AppTheme.surfaceSubtle,
                      foregroundColor: (_isTracking && !_busy) ? Colors.white : AppTheme.muted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      ),
                    ),
                    onPressed: (!_isTracking || _busy) ? null : _stopTracking,
                    child: const Text(
                      'Stop Trip',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic Destination Search & Selection Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(
                color: _selectedDestination != null ? AppTheme.primaryColor : AppTheme.borderLight,
                width: _selectedDestination != null ? 1.5 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x140F172A), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search destination or tap map...',
                    hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 13, fontFamily: 'Inter'),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 20),
                    suffixIcon: _selectedDestination != null || _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.muted),
                            onPressed: _clearDestination,
                          )
                        : (_isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                ),
                              )
                            : null),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 13, color: AppTheme.text, fontFamily: 'Inter'),
                ),
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        final loc = _searchResults[idx];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            loc.isCampusStop ? Icons.directions_bus_rounded : Icons.location_on_outlined,
                            color: loc.isCampusStop ? AppTheme.primaryColor : AppTheme.muted,
                            size: 18,
                          ),
                          title: Text(
                            loc.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                          ),
                          subtitle: Text(
                            loc.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                          ),
                          trailing: loc.isCampusStop
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySubtle,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'CAMPUS',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                )
                              : null,
                          onTap: () => _setDestination(loc),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_activeReportedIssue != null && _activeReportedIssue != 'running') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SOS Alert Active: ${_activeReportedIssue!.toUpperCase()}. Students notified.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showReportIssueSheet,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Change', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Interactive Dynamic Map View with Tap-to-Select
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppTheme.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13.5,
                    onTap: (tapPosition, point) => _onMapTapped(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cbts.transport',
                    ),
                    PolylineLayer(polylines: _polylines),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F0F172A), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.my_location_rounded, size: 20, color: AppTheme.text),
                      tooltip: 'Locate & Broadcast GPS',
                      onPressed: _refreshGpsLocation,
                    ),
                  ),
                ),
                // 1-Tap Emergency SOS Button
                Positioned(
                  right: 8,
                  top: 50,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (_activeReportedIssue != null && _activeReportedIssue != 'running')
                          ? AppTheme.error
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F0F172A), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: (_activeReportedIssue != null && _activeReportedIssue != 'running')
                            ? Colors.white
                            : AppTheme.error,
                      ),
                      tooltip: 'Report Breakdown / SOS',
                      onPressed: _showReportIssueSheet,
                    ),
                  ),
                ),
                // Glassmorphism Floating ETA & Distance HUD
                if (_selectedDestination != null && _roadDistanceMeters != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 48,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: LiveEtaHud(
                        destinationName: _selectedDestination!.name,
                        distanceText: OsrmRoutingService.formatDistance(_roadDistanceMeters!),
                        etaText: OsrmRoutingService.formatEta(_roadDurationSeconds ?? 0),
                        onTap: _centerRouteCamera,
                        accentColor: AppTheme.primaryColor,
                        isRoadRoute: _isRoadGeometry,
                      ),
                    ),
                  ),
                if (_selectedDestination != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x140F172A), blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation_rounded, color: AppTheme.primaryColor, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Navigating to: ${_selectedDestination!.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _clearDestination,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.error,
                                ),
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
          const SizedBox(height: 16),

          // Android Foreground Notification Preview matching Figma 2:4388 & 2:4389
          const Text(
            'ANDROID FOREGROUND NOTIFICATION · PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
              fontFamily: 'Inter',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: AppTheme.primaryColor),
                    SizedBox(width: 6),
                    Text(
                      'TrackItRide · Ongoing',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.muted, fontFamily: 'Inter'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sharing live location · Bus ${widget.busNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Location sharing continues in the background even if the app is closed.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
