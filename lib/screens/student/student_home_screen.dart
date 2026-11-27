import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/supabase_service.dart';
import '../../services/notifications_service.dart';
import '../../shared/status_chip.dart';
import '../../shared/theme.dart';
import 'student_search_screen.dart';
import 'student_location_screen.dart';
import 'student_routes_screen.dart';
import 'student_notifications_screen.dart';
import 'student_profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;

  Map<String, dynamic>? _commuterProfile;
  StreamSubscription<Map<String, dynamic>?>? _busLiveSub;
  StreamSubscription<List<Map<String, dynamic>>>? _announcementsSub;
  String _previousBusStatus = 'idle';
  bool _hasAlertedApproach = false;
  Map<String, dynamic>? _liveTelemetry;

  int _unreadNotificationsCount = 0;
  Map<String, dynamic>? _latestAnnouncement;
  String? _lastNotifiedAnnouncementId;

  @override
  void initState() {
    super.initState();
    _loadCommuterProfile();
    _initAnnouncementListener();
  }

  @override
  void dispose() {
    _busLiveSub?.cancel();
    _announcementsSub?.cancel();
    super.dispose();
  }

  Future<void> _initAnnouncementListener() async {
    try {
      final initialAnn = await SupabaseService.getAnnouncements();
      if (!mounted) return;
      _updateAnnouncements(initialAnn, isInitial: true);
    } catch (_) {}

    _announcementsSub = SupabaseService.streamAnnouncements().listen((items) {
      if (!mounted) return;
      _updateAnnouncements(items, isInitial: false);
    }, onError: (e) {
      debugPrint('Student announcement stream error: $e');
    });
  }

  Future<void> _updateAnnouncements(List<Map<String, dynamic>> items, {bool isInitial = false}) async {
    if (items.isEmpty) {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = 0;
          _latestAnnouncement = null;
        });
      }
      return;
    }

    final latest = items.first;
    final latestId = latest['id']?.toString();

    int unread = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenStr = prefs.getString('cbts_last_seen_notification_time');
      if (lastSeenStr != null) {
        final lastSeen = DateTime.tryParse(lastSeenStr);
        if (lastSeen != null) {
          for (final it in items) {
            final cat = DateTime.tryParse(it['created_at']?.toString() ?? '');
            if (cat != null && cat.isAfter(lastSeen)) {
              unread++;
            }
          }
        } else {
          unread = items.length;
        }
      } else {
        unread = items.length;
      }
    } catch (_) {
      unread = items.length;
    }

    if (mounted) {
      setState(() {
        _latestAnnouncement = latest;
        _unreadNotificationsCount = unread;
      });
    }

    // If new announcement arrived in real-time, alert student with a banner
    if (!isInitial && latestId != null && latestId != _lastNotifiedAnnouncementId) {
      _lastNotifiedAnnouncementId = latestId;
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest['title'] ?? 'New Transit Notice',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (latest['body'] != null)
                        Text(
                          latest['body'].toString(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: const Color(0xFF60A5FA),
              onPressed: _openNotifications,
            ),
          ),
        );
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentNotificationsScreen()),
    );
    if (mounted) {
      setState(() {
        _unreadNotificationsCount = 0;
      });
    }
  }

  Future<void> _loadCommuterProfile() async {
    try {
      final profile = await SupabaseService.getMyCommuterProfile();
      if (!mounted) return;
      setState(() {
        _commuterProfile = profile;
      });

      final busId = profile?['default_bus_id']?.toString();
      if (busId != null && busId.isNotEmpty) {
        _startBusAlertListener(busId);
      } else {
        _busLiveSub?.cancel();
      }
    } catch (e) {
      debugPrint('Error loading commuter profile: $e');
    }
  }

  void _startBusAlertListener(String busId) {
    _busLiveSub?.cancel();
    _previousBusStatus = 'idle';
    _hasAlertedApproach = false;

    _busLiveSub = SupabaseService.streamBusLive(busId).listen((row) {
      if (!mounted || row == null) return;

      setState(() {
        _liveTelemetry = row;
      });

      final status = '${row['status'] ?? 'idle'}';
      final busLat = (row['latitude'] as num?)?.toDouble();
      final busLng = (row['longitude'] as num?)?.toDouble();
      final busCode = _commuterProfile?['bus_code'] ?? 'Your Bus';
      final routeName = _commuterProfile?['route_name'] ?? 'College Route';
      final stopName = _commuterProfile?['stop_name'] ?? 'Your Stop';
      final stopLat = _commuterProfile?['stop_latitude'] as double?;
      final stopLng = _commuterProfile?['stop_longitude'] as double?;

      // 1. Bus started trip
      if (status == 'running' && _previousBusStatus != 'running') {
        _showTripStartAlert(busCode: busCode, routeName: routeName);
      }

      // 2. Bus approaching stop
      if (status == 'running' && busLat != null && busLng != null && stopLat != null && stopLng != null) {
        final distanceMeters = Geolocator.distanceBetween(busLat, busLng, stopLat, stopLng);
        if (distanceMeters <= 1500 && !_hasAlertedApproach) {
          _hasAlertedApproach = true;
          _showProximityAlert(
            busCode: busCode,
            stopName: stopName,
            distanceMeters: distanceMeters.round(),
          );
        } else if (distanceMeters > 3000) {
          _hasAlertedApproach = false;
        }
      }

      _previousBusStatus = status;
    }, onError: (e) {
      debugPrint('Bus alert listener error: $e');
    });
  }

  void _showTripStartAlert({required String busCode, required String routeName}) {
    NotificationsService.addBusAlert(
      title: 'Track Your Bus - Trip Started!',
      body: 'Bus $busCode has started its trip on $routeName.',
      busCode: busCode,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppTheme.successBg, shape: BoxShape.circle),
              child: const Icon(Icons.directions_bus, color: AppTheme.success, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Track Your Bus!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bus $busCode has started its trip on $routeName.', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            const Text(
              'The driver / faculty-incharge is now on the route and moving. Tap below to track the live position on the map.',
              style: TextStyle(fontSize: 13, color: AppTheme.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedIndex = 1); // Switch to Live Map tab
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            icon: const Icon(Icons.location_on, color: Colors.white, size: 18),
            label: const Text('Track Live', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProximityAlert({
    required String busCode,
    required String stopName,
    required int distanceMeters,
  }) {
    NotificationsService.addBusAlert(
      title: 'Track Your Bus - Approaching Stop!',
      body: 'Bus $busCode is approaching $stopName (~$distanceMeters m away).',
      busCode: busCode,
      stopName: stopName,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppTheme.warningBg, shape: BoxShape.circle),
              child: const Icon(Icons.notification_important, color: AppTheme.warning, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Bus Approaching Stop!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bus $busCode is approaching your stop ($stopName)!',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Estimated distance: ~$distanceMeters meters away. Please head to your boarding point now.',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedIndex = 1); // Switch to Live Map tab
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.liveMarker),
            icon: const Icon(Icons.map, color: Colors.white, size: 18),
            label: const Text('Track Bus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
    );
    if (updated == true && mounted) {
      _loadCommuterProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePageContent(
        commuterProfile: _commuterProfile,
        liveTelemetry: _liveTelemetry,
        unreadNotificationsCount: _unreadNotificationsCount,
        latestAnnouncement: _latestAnnouncement,
        onOpenProfile: _openProfile,
        onTrackLive: () => setState(() => _selectedIndex = 1),
        onOpenRoutes: () => setState(() => _selectedIndex = 2),
        onOpenNotifications: _openNotifications,
      ),
      const StudentLocationScreen(),
      const StudentRoutesScreen(),
      const StudentProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: AppTheme.text.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.directions_bus, 'Home'),
                _buildNavItem(1, Icons.location_on_outlined, 'Live'),
                _buildNavItem(2, Icons.alt_route, 'Routes'),
                _buildNavItem(3, Icons.person_outline, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (index == 3) {
          _loadCommuterProfile();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
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

class HomePageContent extends StatelessWidget {
  final Map<String, dynamic>? commuterProfile;
  final Map<String, dynamic>? liveTelemetry;
  final int unreadNotificationsCount;
  final Map<String, dynamic>? latestAnnouncement;
  final VoidCallback onOpenProfile;
  final VoidCallback onTrackLive;
  final VoidCallback onOpenRoutes;
  final VoidCallback onOpenNotifications;

  const HomePageContent({
    super.key,
    required this.commuterProfile,
    required this.liveTelemetry,
    this.unreadNotificationsCount = 0,
    this.latestAnnouncement,
    required this.onOpenProfile,
    required this.onTrackLive,
    required this.onOpenRoutes,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final userName = commuterProfile?['name']?.toString().split(' ').first ?? 'Commuter';
    final busCode = commuterProfile?['bus_code'];
    final routeName = commuterProfile?['route_name'] ?? 'Route not set';
    final stopName = commuterProfile?['stop_name'] ?? 'Stop not selected';
    final hasBus = busCode != null && busCode.toString().isNotEmpty;

    final isLiveRunning = liveTelemetry?['status'] == 'running';
    final speed = (liveTelemetry?['speed_mps'] as num?)?.toDouble();
    final speedKmH = speed != null ? (speed * 3.6).round() : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student / App Bar matching Figma node 7:1564
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TrackItRide',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontFamily: 'Inter',
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.text, size: 26),
                      onPressed: onOpenNotifications,
                    ),
                    if (unreadNotificationsCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              unreadNotificationsCount > 9 ? '9+' : '$unreadNotificationsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Student Greeting matching Figma node 7:2108
            Text(
              'Good morning, $userName',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your ride, right on time.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.muted,
                fontFamily: 'Inter',
              ),
            ),

            // Campus Notice Banner if latest announcement exists
            if (latestAnnouncement != null) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: onOpenNotifications,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Color(0xFF16A34A), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'CAMPUS NOTICE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                    letterSpacing: 0.5,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  'View all >',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              latestAnnouncement!['title'] ?? 'Transit Update',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (latestAnnouncement!['body'] != null)
                              Text(
                                latestAnnouncement!['body'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Search Bar matching Figma Student Search (node 7:1675)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentSearchScreen()),
                );
              },
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.text.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppTheme.muted, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Find your bus or route...',
                        style: TextStyle(color: AppTheme.muted, fontSize: 14, fontFamily: 'Inter'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // "My bus" Section Header matching Figma node 7:2121
            const Text(
              'My bus',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 10),

            // Bus Card matching Figma node 7:2122
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppTheme.surfaceSubtle),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.text.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hasBus ? AppTheme.primarySubtle : AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        ),
                        child: Icon(
                          Icons.directions_bus,
                          color: hasBus ? AppTheme.primaryColor : AppTheme.muted,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasBus ? 'Bus $busCode' : 'No bus selected',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      if (hasBus)
                        StatusChip(
                          type: isLiveRunning ? StatusChipType.live : StatusChipType.taken,
                          label: isLiveRunning ? 'LIVE' : 'IDLE',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasBus ? routeName : 'Enter your bus number to sync arrival time & alerts.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasBus) ...[
                    Text(
                      isLiveRunning
                          ? (speedKmH != null ? 'Running · $speedKmH km/h' : 'Arrives soon')
                          : 'Not started yet',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Boarding: $stopName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.muted,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      if (hasBus) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onTrackLive,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                              ),
                            ),
                            icon: const Icon(Icons.location_on, size: 18, color: Colors.white),
                            label: const Text('Track Live', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenProfile,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                            ),
                          ),
                          icon: const Icon(Icons.edit, size: 18, color: AppTheme.primaryColor),
                          label: Text(
                            hasBus ? 'Change Bus' : 'Enter Bus No',
                            style: const TextStyle(color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // "Quick actions" Section Header matching Figma node 7:2135
            const Text(
              'Quick actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),

            // Quick Actions Grid matching Figma node 7:2136
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.location_on_outlined,
                    label: 'Live Location',
                    onTap: onTrackLive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.alt_route,
                    label: 'Routes & Stops',
                    onTap: onOpenRoutes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    onTap: onOpenNotifications,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.rate_review_outlined,
                    label: 'Feedback',
                    onTap: () => _showFeedbackDialog(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppTheme.surfaceSubtle),
          boxShadow: [
            BoxShadow(
              color: AppTheme.text.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: const Text('Commuter Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share your experience or report an issue with the college bus service:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your comments here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                final email = SupabaseService.currentEmail ?? 'Anonymous';
                await SupabaseService.submitFeedback(feedback: text, email: email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you! Your feedback has been received.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
