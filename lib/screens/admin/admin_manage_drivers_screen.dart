import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'admin_register_driver_screen.dart';
import 'admin_driver_edit_screen.dart';

class AdminManageDriversScreen extends StatefulWidget {
  const AdminManageDriversScreen({super.key});

  @override
  _AdminManageDriversScreenState createState() =>
      _AdminManageDriversScreenState();
}

class _AdminManageDriversScreenState extends State<AdminManageDriversScreen> {
  late Future<List<Map<String, dynamic>>> _driversFuture;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  void _loadDrivers() {
    setState(() {
      _driversFuture = SupabaseService.getDrivers();
    });
  }

  Future<void> deleteDriver(String driverId) async {
    try {
      await SupabaseService.deleteDriver(driverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver removed successfully from Supabase!')),
        );
        _loadDrivers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting driver: ${e.toString()}')),
        );
      }
    }
  }

  void _confirmDeleteDriver(String driverId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Driver'),
        content: const Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              deleteDriver(driverId);
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
        title: const Text('Manage Drivers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrivers,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _driversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading drivers: ${snapshot.error}'));
          }

          final driverList = snapshot.data ?? [];
          if (driverList.isEmpty) {
            return const Center(child: Text('No drivers found in Supabase. Tap + to register one.'));
          }

          return ListView.builder(
            itemCount: driverList.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              final driver = driverList[index];
              final driverId = driver['id'];
              final name = driver['name'] ?? 'Driver';
              final email = driver['email'] ?? '';
              final phone = driver['phone'] ?? '+91';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(name),
                  subtitle: Text('Email: $email\nPhone: $phone'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminDriverEditScreen(
                                driverId: driverId,
                                name: name,
                                email: email,
                                phone: phone,
                                licenseNumber: 'DL-ACTIVE',
                              ),
                            ),
                          );
                          _loadDrivers();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteDriver(driverId),
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
            MaterialPageRoute(builder: (context) => const AdminRegisterDriverScreen()),
          );
          _loadDrivers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
