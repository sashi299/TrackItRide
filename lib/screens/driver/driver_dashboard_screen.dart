import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/gps_tracking_service.dart';
import '../../shared/theme.dart';
import 'driver_profile_screen.dart';
import 'driver_view_feedback_screen.dart';
import 'driver_route_overview_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>?> driverAssignmentFuture;
  String? driverEmail = SupabaseService.currentEmail;

  @override
  void initState() {
    super.initState();
    if (driverEmail != null) {
      driverAssignmentFuture = SupabaseService.getDriverAssignment(driverEmail!);
    } else {
      driverAssignmentFuture = Future.value(null);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    await GpsTrackingService.stopTracking();
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/driver_login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: driverAssignmentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data ?? {};
        final busNumber = data['busNumber'] ?? 'BUS-12';
        final routeName = data['routeName'] ?? 'Main Campus Route';
        final tripId = data['tripId'] ?? '';
        final routeId = data['routeId'] ?? '';

        final List<Widget> widgetOptions = [
          DriverHomePageContent(
            key: const PageStorageKey('DriverHomePageContent'),
            busNumber: busNumber,
            routeName: routeName,
            tripId: tripId,
            routeId: routeId,
          ),
          DriverRouteOverviewScreen(
            driverEmail: driverEmail ?? '',
            busNumber: busNumber,
            routeName: routeName,
          ),
          const DriverProfileScreen(),
          const DriverViewFeedbackScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text("Driver Dashboard"),
            backgroundColor: AppTheme.primaryColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: widgetOptions,
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Console'),
              BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Route'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              BottomNavigationBarItem(icon: Icon(Icons.feedback), label: 'Feedback'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            backgroundColor: AppTheme.primaryColor,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
          ),
        );
      },
    );
  }
}

class DriverHomePageContent extends StatefulWidget {
  final String busNumber;
  final String routeName;
  final String tripId;
  final String routeId;

  const DriverHomePageContent({
    required this.busNumber,
    required this.routeName,
    required this.tripId,
    required this.routeId,
    super.key,
  });

  @override
  _DriverHomePageContentState createState() => _DriverHomePageContentState();
}

class _DriverHomePageContentState extends State<DriverHomePageContent> {
  bool _isTracking = false;
  Position? _currentLocation;
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<LatLng> routeCoordinates = [];

  @override
  void initState() {
    super.initState();
    _loadRouteStops();
  }

  Future<void> _loadRouteStops() async {
    try {
      final routes = await SupabaseService.getRoutes();
      if (routes.isNotEmpty) {
        final r = routes.first;
        final stops = await SupabaseService.getStopsForRoute(r['id']);
        List<LatLng> coords = [];
        for (var stop in stops) {
          final lat = (stop['latitude'] as num).toDouble();
          final lng = (stop['longitude'] as num).toDouble();
          final pos = LatLng(lat, lng);
          coords.add(pos);
          _markers.add(Marker(
            markerId: MarkerId(stop['id']),
            position: pos,
            infoWindow: InfoWindow(title: stop['name'] ?? 'Stop'),
          ));
        }

        if (coords.isNotEmpty) {
          setState(() {
            routeCoordinates = coords;
            _polylines.add(Polyline(
              polylineId: const PolylineId('routePolyline'),
              points: coords,
              color: Colors.blue,
              width: 5,
            ));
          });
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _startTracking() async {
    final success = await GpsTrackingService.startTracking(
      tripId: widget.tripId.isNotEmpty ? widget.tripId : 'active-trip',
      onLocationUpdate: (Position pos) {
        if (!mounted) return;
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentLocation = pos;
          _markers.removeWhere((m) => m.markerId.value == 'driverLocation');
          _markers.add(Marker(
            markerId: const MarkerId('driverLocation'),
            position: latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: "My Bus (Live GPS)"),
          ));
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      },
    );

    if (success) {
      if (mounted) {
        setState(() => _isTracking = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip started! Live GPS streaming to Supabase.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start tracking. Please grant location permissions.')),
        );
      }
    }
  }

  Future<void> _stopTracking() async {
    await GpsTrackingService.stopTracking();
    setState(() => _isTracking = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ended. Location streaming stopped.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Driver: ${SupabaseService.currentEmail ?? 'Active'}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.directions_bus, size: 18, color: Colors.white),
                    label: Text(widget.busNumber, style: const TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.alt_route, size: 18),
                    label: Text(widget.routeName),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _isTracking ? null : _startTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    label: const Text('Start Trip', style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    onPressed: _isTracking ? _stopTracking : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    label: const Text('Stop Trip', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation != null
                  ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
                  : const LatLng(12.9716, 77.5946),
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
          ),
        ),
      ],
    );
  }
}
