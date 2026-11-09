import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  _DriverProfileScreenState createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  late Future<Map<String, dynamic>?> _driverData;

  Future<Map<String, dynamic>?> fetchDriverData(String email) async {
    try {
      final user = await SupabaseService.client
          .from('users')
          .select('*')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      final assignment = await SupabaseService.getDriverAssignment(email);

      return {
        'name': user?['name'] ?? 'College Driver',
        'email': email,
        'phone': user?['phone'] ?? '+91 9876543210',
        'role': 'Driver',
        'busNumber': assignment?['busNumber'] ?? 'BUS-12',
        'routeName': assignment?['routeName'] ?? 'Campus Main Route',
      };
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final email = SupabaseService.currentEmail;
    if (email != null) {
      _driverData = fetchDriverData(email);
    } else {
      _driverData = Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryColor,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _driverData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final name = data['name'] ?? 'Driver';
          final email = data['email'] ?? SupabaseService.currentEmail ?? 'N/A';
          final phone = data['phone'] ?? 'N/A';
          final busNumber = data['busNumber'] ?? 'BUS-12';
          final routeName = data['routeName'] ?? 'Main Campus Route';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 45,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone, color: Colors.green),
                        title: const Text('Phone Number'),
                        subtitle: Text(phone),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.directions_bus, color: Colors.blue),
                        title: const Text('Assigned Bus'),
                        subtitle: Text(busNumber),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.alt_route, color: Colors.orange),
                        title: const Text('Assigned Route'),
                        subtitle: Text(routeName),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
