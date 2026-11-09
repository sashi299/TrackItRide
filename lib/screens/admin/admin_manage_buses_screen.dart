import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'admin_register_bus_screen.dart';

class AdminManageBusesScreen extends StatefulWidget {
  const AdminManageBusesScreen({super.key});

  @override
  _AdminManageBusesScreenState createState() => _AdminManageBusesScreenState();
}

class _AdminManageBusesScreenState extends State<AdminManageBusesScreen> {
  late Future<List<Map<String, dynamic>>> _busesFuture;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  void _loadBuses() {
    setState(() {
      _busesFuture = SupabaseService.getBuses();
    });
  }

  Future<void> deleteBus(String busId) async {
    try {
      await SupabaseService.deleteBus(busId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus deleted successfully from Supabase!')),
        );
        _loadBuses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting bus: ${e.toString()}')),
        );
      }
    }
  }

  void _confirmDeleteBus(String busId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bus'),
        content: const Text('Are you sure you want to delete this bus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              deleteBus(busId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBuses,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _busesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading buses: ${snapshot.error}'));
          }

          final busList = snapshot.data ?? [];
          if (busList.isEmpty) {
            return const Center(child: Text('No buses available in Supabase. Tap + to add.'));
          }

          return ListView.builder(
            itemCount: busList.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              final bus = busList[index];
              final busId = bus['id'];
              final busNumber = bus['code'] ?? 'BUS';
              final numberPlate = bus['label'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.directions_bus, color: Colors.white),
                  ),
                  title: Text('Bus Number: $busNumber'),
                  subtitle: Text('Plate: $numberPlate • Capacity: ${bus['capacity'] ?? 40}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminRegisterBusScreen(
                                busId: busId,
                                busNumber: busNumber,
                                numberPlate: numberPlate,
                              ),
                            ),
                          );
                          _loadBuses();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteBus(busId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminRegisterBusScreen()),
          );
          _loadBuses();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
