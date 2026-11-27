import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';
import '../../supabase_config.dart';

/// Admin Dashboard Screen matching Figma AM02 · Dashboard (12:3370),
/// AD02 · Dashboard (12:3351), AT01 (12:3389), and AM21 · Administration menu (12:9426).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  StreamSubscription<List<Map<String, dynamic>>>? _fleetLiveSub;

  int _totalBuses = 0;
  int _activeTrips = 0;
  int _totalDrivers = 0;
  int _pendingApprovals = 0;
  Map<String, dynamic>? _recentAnnouncement;
  List<Map<String, dynamic>> _liveBuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardMetrics();
    _subscribeToFleetRealtime();
  }

  @override
  void dispose() {
    _fleetLiveSub?.cancel();
    super.dispose();
  }

  void _subscribeToFleetRealtime() {
    _fleetLiveSub = SupabaseService.streamAllLiveBuses().listen((liveRows) {
      if (!mounted) return;
      final liveMap = <String, Map<String, dynamic>>{};
      for (final r in liveRows) {
        final busId = r['bus_id']?.toString();
        if (busId != null) {
          liveMap[busId] = r;
        }
      }

      setState(() {
        int runningCount = 0;
        for (final b in _liveBuses) {
          final busId = b['id']?.toString();
          if (busId != null && liveMap.containsKey(busId)) {
            final live = liveMap[busId]!;
            b['latitude'] = (live['latitude'] as num?)?.toDouble();
            b['longitude'] = (live['longitude'] as num?)?.toDouble();
            b['speed_mps'] = (live['speed_mps'] as num?)?.toDouble();
            b['heading'] = (live['heading'] as num?)?.toDouble();
            b['status'] = live['status'] ?? 'idle';
            b['updated_at'] = live['updated_at'];
          }
          if (b['status'] == 'running') {
            runningCount++;
          }
        }
        _activeTrips = runningCount;
      });
    }, onError: (e) {
      debugPrint('Fleet realtime stream error: $e');
    });
  }

  Future<void> _loadDashboardMetrics() async {
    setState(() => _isLoading = true);
    try {
      final fleetFuture = SupabaseService.getFleetWithLiveLocations();
      final driversFuture = SupabaseService.getDrivers();
      final announcementsFuture = SupabaseService.getAnnouncements();

      final results = await Future.wait([fleetFuture, driversFuture, announcementsFuture]);
      final fleet = results[0];
      final drivers = results[1];
      final announcements = results[2];

      int pendingCount = 0;
      for (final d in drivers) {
        if (d['approved'] == false || d['approved'] == null) {
          pendingCount++;
        }
      }

      int runningCount = 0;
      for (final b in fleet) {
        if (b['status'] == 'running') {
          runningCount++;
        }
      }

      if (mounted) {
        setState(() {
          _totalBuses = fleet.length;
          _activeTrips = runningCount;
          _totalDrivers = drivers.length;
          _pendingApprovals = pendingCount;
          _liveBuses = fleet;
          _recentAnnouncement = announcements.isNotEmpty ? announcements.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/admin_login');
    }
  }

  void _showBusDetailModal(Map<String, dynamic> bus) {
    final code = (bus['code'] ?? 'BUS').toString();
    final label = (bus['label'] ?? 'Campus Shuttle').toString();
    final capacity = bus['capacity']?.toString() ?? '40';
    final isRunning = bus['status'] == 'running';
    final lat = (bus['latitude'] as num?)?.toDouble();
    final lng = (bus['longitude'] as num?)?.toDouble();
    final speed = (bus['speed_mps'] as num?)?.toDouble();
    final speedKmh = speed != null ? (speed * 3.6).round() : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isRunning ? AppTheme.liveMarker.withOpacity(0.15) : AppTheme.surfaceSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.directions_bus, color: isRunning ? AppTheme.liveMarker : AppTheme.muted, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.muted,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRunning ? AppTheme.successBg : AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRunning ? 'LIVE · EN ROUTE' : 'IDLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isRunning ? AppTheme.success : AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lat != null && lng != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed, size: 14, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}  ·  $speedKmh km/h',
                      style: const TextStyle(fontSize: 12, fontFamily: 'Inter', fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Capacity: $capacity Seats',
                  style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/admin_manage_buses');
                  },
                  child: const Text('Manage Fleet →'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppTheme.background,
          appBar: _buildAppBar(isDesktop),
          drawer: _buildAdministrationDrawer(),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : isDesktop
                  ? _buildDesktopLayout()
                  : _buildMobileLayout(),
          bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.text),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: 'Administration Menu',
      ),
      title: const Text(
        'Dashboard',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.text,
          fontFamily: 'Inter',
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.text),
          onPressed: _loadDashboardMetrics,
          tooltip: 'Refresh metrics',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// AM21 · Administration menu (12:9426)
  Widget _buildAdministrationDrawer() {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TrackItRide',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          'System Administration',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', '/admin_dashboard', isSelected: true),
                  _buildDrawerItem(Icons.directions_bus_rounded, 'Buses Fleet', '/admin_manage_buses'),
                  _buildDrawerItem(Icons.badge_rounded, 'Drivers / Faculty-Incharge', '/admin_manage_drivers'),
                  _buildDrawerItem(Icons.alt_route_rounded, 'Routes & Stops', '/admin_route_management'),
                  _buildDrawerItem(Icons.sync_alt_rounded, 'Assign Bus Override', '/assign_bus_route'),
                  const Divider(height: 16, color: AppTheme.border),
                  _buildDrawerItem(Icons.campaign_rounded, 'Announcements', '/admin_analytics'),
                  _buildDrawerItem(Icons.mark_email_unread_rounded, 'Feedback Inbox', '/admin_view_feedback'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomButton(
                label: 'Sign out',
                backgroundColor: AppTheme.error,
                height: 48,
                onPressed: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, String route, {bool isSelected = false}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : AppTheme.muted),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppTheme.primaryColor : AppTheme.text,
          fontFamily: 'Inter',
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primarySubtle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: () {
        Navigator.pop(context); // close drawer
        if (!isSelected) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Row 1
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  label: 'Total buses',
                  value: _totalBuses.toString(),
                  icon: Icons.directions_bus_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  label: 'Active trips now',
                  value: _activeTrips.toString(),
                  icon: Icons.play_arrow_rounded,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KPI Row 2
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  label: 'Drivers / Faculty',
                  value: _totalDrivers.toString(),
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  label: 'Pending approvals',
                  value: _pendingApprovals.toString(),
                  icon: Icons.hourglass_top_rounded,
                  color: _pendingApprovals > 0 ? AppTheme.liveMarker : AppTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Live fleet header & Compact Map (Figma node 12:8473)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live fleet · $_activeTrips running',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/admin_manage_buses'),
                child: const Text('View fleet', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactFleetMap(),
          const SizedBox(height: 20),

          // Quick actions (Figma node 12:8504)
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Add bus',
                  height: 48,
                  onPressed: () => Navigator.pushNamed(context, '/admin_register_bus'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  label: 'Approvals $_pendingApprovals',
                  isSecondary: true,
                  height: 48,
                  onPressed: () => Navigator.pushNamed(context, '/admin_manage_drivers'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recent Announcement Card (Figma node 12:8509)
          _buildRecentAnnouncementCard(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4-Column KPI Cards (AD02)
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  label: 'Total buses',
                  value: _totalBuses.toString(),
                  icon: Icons.directions_bus_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  label: 'Active trips now',
                  value: _activeTrips.toString(),
                  icon: Icons.play_arrow_rounded,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  label: 'Drivers / Faculty',
                  value: _totalDrivers.toString(),
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  label: 'Pending approvals',
                  value: _pendingApprovals.toString(),
                  icon: Icons.hourglass_top_rounded,
                  color: _pendingApprovals > 0 ? AppTheme.liveMarker : AppTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Map and Quick Action Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live fleet overview · $_activeTrips running',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 380,
                      child: _buildCompactFleetMap(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: '+ Add New Bus',
                      height: 48,
                      onPressed: () => Navigator.pushNamed(context, '/admin_register_bus'),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: 'Review Driver / Faculty Approvals ($_pendingApprovals)',
                      isSecondary: true,
                      height: 48,
                      onPressed: () => Navigator.pushNamed(context, '/admin_manage_drivers'),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: 'Assign Bus Route Overrides',
                      isSecondary: true,
                      height: 48,
                      onPressed: () => Navigator.pushNamed(context, '/assign_bus_route'),
                    ),
                    const SizedBox(height: 20),
                    _buildRecentAnnouncementCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.muted,
                  fontFamily: 'Inter',
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFleetMap() {
    const campusLatLng = LatLng(SupabaseConfig.defaultCampusLat, SupabaseConfig.defaultCampusLng);

    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: campusLatLng,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cbts.transport',
              ),
              MarkerLayer(
                markers: [
                  // Campus Marker
                  Marker(
                    point: campusLatLng,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, color: Colors.white, size: 20),
                    ),
                  ),
                  // Real live fleet markers - ONLY rendered when trip is running and coordinates are live
                  for (int i = 0; i < _liveBuses.length; i++)
                    if (_liveBuses[i]['status'] == 'running' &&
                        _liveBuses[i]['latitude'] != null &&
                        _liveBuses[i]['longitude'] != null)
                      _buildFleetBusMarker(_liveBuses[i], i),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: InkWell(
              onTap: () => _mapController.move(campusLatLng, 13.0),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  boxShadow: const [
                    BoxShadow(color: Color(0x20000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.my_location, color: AppTheme.primaryColor, size: 20),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                _activeTrips > 0
                    ? 'AITAM Fleet · $_activeTrips live bus${_activeTrips > 1 ? 'es' : ''} en route'
                    : 'AITAM Fleet · Fleet idle in depot (0 running)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _activeTrips > 0 ? AppTheme.success : AppTheme.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildFleetBusMarker(Map<String, dynamic> bus, int index) {
    final lat = (bus['latitude'] as num).toDouble();
    final lng = (bus['longitude'] as num).toDouble();
    final heading = (bus['heading'] as num?)?.toDouble() ?? 0.0;
    final busCode = (bus['code'] ?? 'BUS-${index + 1}').toString();
    final status = (bus['status'] ?? 'running').toString();
    final isIssue = status == 'breakdown' || status == 'delayed' || status == 'traffic_jam';
    final markerColor = isIssue ? AppTheme.error : AppTheme.liveMarker;

    return Marker(
      key: ValueKey('bus_marker_${bus['id'] ?? index}'),
      point: LatLng(lat, lng),
      width: 76,
      height: 60,
      child: GestureDetector(
        onTap: () => _showBusDetailModal(bus),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: heading * (math.pi / 180.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isIssue)
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: markerColor.withOpacity(0.5),
                          blurRadius: isIssue ? 10 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isIssue ? Icons.warning_rounded : Icons.directions_bus,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_drop_up_rounded, color: isIssue ? AppTheme.error : AppTheme.primaryColor, size: 8),
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
                  color: markerColor,
                  width: 1.5,
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
                isIssue ? '⚠️ $busCode' : busCode,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isIssue ? AppTheme.error : AppTheme.text,
                  letterSpacing: 0.2,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnnouncementCard() {
    final title = _recentAnnouncement?['title'] ?? 'Fleet updates';
    final message = _recentAnnouncement?['message'] ?? 'Check routes, timings and approvals regularly.';
    final date = _recentAnnouncement?['created_at']?.toString() ?? 'Today';

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/admin_analytics'),
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.campaign_outlined, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        date.length > 10 ? date.substring(0, 10) : date,
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isSelected: true,
            onTap: () {},
          ),
          _buildBottomNavItem(
            icon: Icons.directions_bus_rounded,
            label: 'Buses',
            isSelected: false,
            onTap: () => Navigator.pushNamed(context, '/admin_manage_buses'),
          ),
          _buildBottomNavItem(
            icon: Icons.people_alt_rounded,
            label: 'Drivers / Faculty',
            isSelected: false,
            onTap: () => Navigator.pushNamed(context, '/admin_manage_drivers'),
          ),
          _buildBottomNavItem(
            icon: Icons.menu_rounded,
            label: 'More',
            isSelected: false,
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryColor : AppTheme.muted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
