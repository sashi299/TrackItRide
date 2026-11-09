import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../../services/supabase_service.dart';

class StudentLocationScreen extends StatefulWidget {
  const StudentLocationScreen({super.key});

  @override
  _StudentLocationScreenState createState() => _StudentLocationScreenState();
}

class _StudentLocationScreenState extends State<StudentLocationScreen> {
  late Future<List<Map<String, dynamic>>> assignedBuses;
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  final Location _location = Location();
  StreamSubscription<List<Map<String, dynamic>>>? _tripSubscription;
  StreamSubscription<LocationData>? _userLocationSubscription;

  @override
  void initState() {
    super.initState();
    assignedBuses = SupabaseService.getAssignedBuses();
    _requestLocationPermission();
    _startUserLocationTracking();
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _userLocationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _location.requestPermission();
    }
  }

  void _startUserLocationTracking() {
    _userLocationSubscription = _location.onLocationChanged.listen((locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        final userPosition = LatLng(locationData.latitude!, locationData.longitude!);
        if (!mounted) return;
        setState(() {
          _markers.removeWhere((marker) => marker.markerId.value == 'userLocation');
          _markers.add(
            Marker(
              markerId: const MarkerId('userLocation'),
              position: userPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'My Location'),
            ),
          );
        });
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Start live tracking of a bus trip using Supabase Realtime
  void _startDriverLocationTracking(String? tripId, String busNumber) {
    _tripSubscription?.cancel();

    _tripSubscription = SupabaseService.streamActiveTrips().listen((trips) {
      if (!mounted) return;

      Map<String, dynamic>? activeTrip;
      if (tripId != null && tripId.isNotEmpty) {
        activeTrip = trips.firstWhere(
          (t) => t['id'] == tripId,
          orElse: () => trips.isNotEmpty ? trips.first : {},
        );
      } else if (trips.isNotEmpty) {
        activeTrip = trips.first;
      }

      if (activeTrip != null && activeTrip.isNotEmpty) {
        final lat = (activeTrip['last_latitude'] as num?)?.toDouble();
        final lng = (activeTrip['last_longitude'] as num?)?.toDouble();

        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          final busPos = LatLng(lat, lng);
          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'driverLocation');
            _markers.add(
              Marker(
                markerId: const MarkerId('driverLocation'),
                position: busPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                infoWindow: InfoWindow(
                  title: 'Bus $busNumber (Live)',
                  snippet: 'Status: ${activeTrip?['status'] ?? 'Running'}',
                ),
              ),
            );
          });

          _mapController?.animateCamera(CameraUpdate.newLatLng(busPos));
        }
      }
    });
  }

  Future<void> _fetchRouteDetails(String? routeId, String routeName) async {
    setState(() {
      _polylines.clear();
      _markers.removeWhere((m) => m.markerId.value != 'userLocation' && m.markerId.value != 'driverLocation');
    });

    try {
      List<Map<String, dynamic>> routes = await SupabaseService.getRoutes();
      Map<String, dynamic>? selectedRoute;

      if (routeId != null && routeId.isNotEmpty) {
        selectedRoute = routes.firstWhere((r) => r['id'] == routeId, orElse: () => routes.first);
      } else {
        selectedRoute = routes.firstWhere((r) => r['name'] == routeName, orElse: () => routes.first);
      }

      if (routes.isNotEmpty) {
        final stops = await SupabaseService.getStopsForRoute(selectedRoute['id']);
        List<LatLng> polylinePoints = [];

        for (var stop in stops) {
          final lat = (stop['latitude'] as num).toDouble();
          final lng = (stop['longitude'] as num).toDouble();
          final stopPos = LatLng(lat, lng);
          polylinePoints.add(stopPos);

          _markers.add(
            Marker(
              markerId: MarkerId(stop['id']),
              position: stopPos,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: stop['name'] ?? 'Stop',
                snippet: 'Stop #${stop['sequence_no']} | Scheduled: ${stop['scheduled_morning'] ?? 'N/A'}',
              ),
            ),
          );
        }

        if (polylinePoints.isNotEmpty) {
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId(selectedRoute?['id'] ?? 'route'),
                points: polylinePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(polylinePoints.first, 13.5),
          );
        }
      }
    } catch (e) {
      // Best-effort route render
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: assignedBuses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final buses = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text("Buses Live Location"),
            backgroundColor: Colors.blue,
          ),
          body: Column(
            children: [
              Expanded(
                flex: 2,
                child: buses.isEmpty
                    ? const Center(child: Text("No buses currently registered in Supabase."))
                    : ListView.builder(
                        itemCount: buses.length,
                        itemBuilder: (context, index) {
                          final bus = buses[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                            child: ListTile(
                              leading: const Icon(Icons.directions_bus, color: Colors.blue),
                              title: Text('Bus: ${bus['busNumber']} (${bus['numberPlate']})'),
                              subtitle: Text('Route: ${bus['routeName']} • Driver: ${bus['driverName']}'),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  _startDriverLocationTracking(bus['tripId'], bus['busNumber']);
                                  _fetchRouteDetails(bus['routeId'], bus['routeName']);
                                },
                                child: const Text("Live Map"),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Expanded(
                flex: 3,
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(12.9716, 77.5946),
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
