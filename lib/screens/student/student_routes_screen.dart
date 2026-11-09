import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class StudentRoutesScreen extends StatefulWidget {
  const StudentRoutesScreen({super.key});

  @override
  _StudentRoutesScreenState createState() => _StudentRoutesScreenState();
}

class _StudentRoutesScreenState extends State<StudentRoutesScreen> {
  late Future<List<Map<String, dynamic>>> routesFuture;

  @override
  void initState() {
    super.initState();
    routesFuture = SupabaseService.getRoutes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Bus Routes'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading routes: ${snapshot.error}'));
          }

          final routes = snapshot.data ?? [];
          if (routes.isEmpty) {
            return const Center(child: Text('No routes registered in Supabase.'));
          }

          return ListView.builder(
            itemCount: routes.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              final route = routes[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      route['code'] ?? 'R',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  title: Text(
                    route['name'] ?? 'Route',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text('Code: ${route['code'] ?? 'N/A'}'),
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: SupabaseService.getStopsForRoute(route['id']),
                      builder: (context, stopSnapshot) {
                        if (stopSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          );
                        }

                        final stops = stopSnapshot.data ?? [];
                        if (stops.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No stops configured for this route.'),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Scheduled Stops:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...stops.map((stop) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.blue.shade700,
                                          child: Text(
                                            '${stop['sequence_no']}',
                                            style: const TextStyle(color: Colors.white, fontSize: 11),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            stop['name'] ?? 'Stop',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          stop['scheduled_morning'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 8),
                            ],
                          ),
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
    );
  }
}
