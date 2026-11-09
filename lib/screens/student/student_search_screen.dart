import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key});

  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  String query = "";
  List<Map<String, dynamic>> routes = [];
  Map<String, List<Map<String, dynamic>>> routeStops = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRoutesAndStops();
  }

  Future<void> fetchRoutesAndStops() async {
    try {
      final fetchedRoutes = await SupabaseService.getRoutes();
      final Map<String, List<Map<String, dynamic>>> stopsMap = {};

      for (var route in fetchedRoutes) {
        final stops = await SupabaseService.getStopsForRoute(route['id']);
        stopsMap[route['id']] = stops;
      }

      if (mounted) {
        setState(() {
          routes = fetchedRoutes;
          routeStops = stopsMap;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRoutes = routes.where((route) {
      final routeNameMatches = (route['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase());
      final routeCodeMatches = (route['code'] ?? '').toString().toLowerCase().contains(query.toLowerCase());
      final stops = routeStops[route['id']] ?? [];
      final stopMatches = stops.any((s) => (s['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase()));
      return routeNameMatches || routeCodeMatches || stopMatches;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Routes & Stops'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Search by route name, code, or stop...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredRoutes.isEmpty
                    ? const Center(child: Text('No matching routes found.'))
                    : ListView.builder(
                        itemCount: filteredRoutes.length,
                        itemBuilder: (context, index) {
                          final route = filteredRoutes[index];
                          final stops = routeStops[route['id']] ?? [];

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                            child: ExpansionTile(
                              title: Text(
                                route['name'] ?? 'Route',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Code: ${route['code']} • ${stops.length} stops'),
                              children: stops.map((stop) {
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 10,
                                    child: Text(
                                      '${stop['sequence_no']}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  title: Text(stop['name'] ?? 'Stop'),
                                  trailing: Text(stop['scheduled_morning'] ?? ''),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
