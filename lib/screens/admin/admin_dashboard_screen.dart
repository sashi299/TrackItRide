import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await SupabaseService.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/admin_login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard (Supabase)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: const Text('Manage Buses'),
                subtitle: const Text('Add, edit, and delete fleet vehicles'),
                leading: const Icon(Icons.directions_bus, color: Colors.blue),
                onTap: () {
                  Navigator.pushNamed(context, '/admin_manage_buses');
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: const Text('Manage Drivers'),
                subtitle: const Text('Driver rosters and phone records'),
                leading: const Icon(Icons.person, color: Colors.green),
                onTap: () {
                  Navigator.pushNamed(context, '/admin_manage_drivers');
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: const Text('Route Management'),
                subtitle: const Text('Create and manage bus routes and stops'),
                leading: const Icon(Icons.route, color: Colors.orange),
                onTap: () {
                  Navigator.pushNamed(context, '/admin_route_management');
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: const Text('Bus & Route Assignment'),
                subtitle: const Text('Assign buses and routes to drivers'),
                leading: const Icon(Icons.assignment, color: Colors.purple),
                onTap: () {
                  Navigator.pushNamed(context, '/assign_bus_route');
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: const Text('System Announcements'),
                subtitle: const Text('Send alerts to student & driver apps'),
                leading: const Icon(Icons.campaign, color: Colors.amber),
                onTap: () {
                  Navigator.pushNamed(context, '/admin_analytics');
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: const Text('Student & Driver Feedback'),
                subtitle: const Text('View submitted reviews and issues'),
                leading: const Icon(Icons.feedback, color: Colors.teal),
                onTap: () {
                  Navigator.pushNamed(context, '/admin_view_feedback');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
