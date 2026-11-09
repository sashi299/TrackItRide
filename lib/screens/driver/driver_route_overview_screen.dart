import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';

class DriverRouteOverviewScreen extends StatefulWidget {
  final String driverEmail;
  final String busNumber;
  final String routeName;
  final String busId;
  final String routeId;

  const DriverRouteOverviewScreen({
    required this.driverEmail,
    required this.busNumber,
    required this.routeName,
    this.busId = '',
    this.routeId = '',
    super.key,
  });

  @override
  _DriverRouteOverviewScreenState createState() =>
      _DriverRouteOverviewScreenState();
}

class _DriverRouteOverviewScreenState extends State<DriverRouteOverviewScreen> {
  late Future<List<Map<String, dynamic>>> stopsFuture;

  @override
  void initState() {
    super.initState();
    stopsFuture = _fetchStops();
  }

  Future<List<Map<String, dynamic>>> _fetchStops() async {
    try {
      final routes = await SupabaseService.getRoutes();
      if (routes.isNotEmpty) {
        final route = routes.first;
        return await SupabaseService.getStopsForRoute(route['id']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Route: ${widget.routeName}"),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: stopsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stops = snapshot.data ?? [];
          if (stops.isEmpty) {
            return const Center(child: Text("No stops found for this route."));
          }

          return ListView.builder(
            itemCount: stops.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              final stop = stops[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      '${stop['sequence_no']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    stop['name'] ?? 'Stop',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Lat: ${stop['latitude']}, Lng: ${stop['longitude']}'),
                  trailing: Text(
                    stop['scheduled_morning'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
