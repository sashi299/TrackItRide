import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminRouteManagementScreen extends StatefulWidget {
  const AdminRouteManagementScreen({super.key});

  @override
  _AdminRouteManagementScreenState createState() =>
      _AdminRouteManagementScreenState();
}

class _AdminRouteManagementScreenState
    extends State<AdminRouteManagementScreen> {
  late Future<List<Map<String, dynamic>>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  void _loadRoutes() {
    setState(() {
      _routesFuture = SupabaseService.getRoutes();
    });
  }

  Future<void> _addRouteDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Route Name (e.g. North Gate - Campus)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Route Code (e.g. R15)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty && codeController.text.trim().isNotEmpty) {
                await SupabaseService.addRoute(
                  routeName: nameController.text.trim(),
                  routeCode: codeController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadRoutes();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addStopDialog(String routeId) async {
    final nameController = TextEditingController();
    final seqController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stop to Route'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Stop Name'),
              ),
              TextField(
                controller: seqController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sequence Number (1, 2, 3...)'),
              ),
              TextField(
                controller: latController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Latitude (e.g. 12.9716)'),
              ),
              TextField(
                controller: lngController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Longitude (e.g. 77.5946)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final seq = int.tryParse(seqController.text.trim()) ?? 1;
              final lat = double.tryParse(latController.text.trim()) ?? 0.0;
              final lng = double.tryParse(lngController.text.trim()) ?? 0.0;

              if (name.isNotEmpty && lat != 0.0 && lng != 0.0) {
                await SupabaseService.addStop(
                  routeId: routeId,
                  name: name,
                  sequenceNo: seq,
                  latitude: lat,
                  longitude: lng,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadRoutes();
              }
            },
            child: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoute(String routeId) async {
    await SupabaseService.deleteRoute(routeId);
    _loadRoutes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoutes,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data ?? [];
          if (routes.isEmpty) {
            return const Center(child: Text('No routes configured. Tap + to add one.'));
          }

          return ListView.builder(
            itemCount: routes.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              final route = routes[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  leading: CircleAvatar(child: Text(route['code'] ?? 'R')),
                  title: Text(route['name'] ?? 'Route', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Code: ${route['code']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_location_alt, color: Colors.green),
                        tooltip: 'Add Stop',
                        onPressed: () => _addStopDialog(route['id']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Route',
                        onPressed: () => _deleteRoute(route['id']),
                      ),
                    ],
                  ),
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: SupabaseService.getStopsForRoute(route['id']),
                      builder: (context, snap) {
                        final stops = snap.data ?? [];
                        if (stops.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('No stops added yet.'),
                          );
                        }
                        return Column(
                          children: stops
                              .map((s) => ListTile(
                                    dense: true,
                                    leading: Text('#${s['sequence_no']}'),
                                    title: Text(s['name']),
                                    subtitle: Text('Lat: ${s['latitude']}, Lng: ${s['longitude']}'),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRouteDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
