import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Announcements & Alerts")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.streamAnnouncements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final announcements = snapshot.data ?? [];
          if (announcements.isEmpty) {
            return const Center(
              child: Text(
                'No alerts or notifications right now',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: announcements.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              final a = announcements[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.campaign, color: Colors.white),
                  ),
                  title: Text(
                    a['title'] ?? 'Notice',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(a['body'] ?? ''),
                  trailing: Text(
                    (a['created_at'] != null)
                        ? (a['created_at'].toString().substring(0, 10))
                        : '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
