import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';

class DriverViewFeedbackScreen extends StatelessWidget {
  const DriverViewFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Feedback'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseService.getFeedbacks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedbackList = snapshot.data ?? [];
          if (feedbackList.isEmpty) {
            return const Center(child: Text('No feedback recorded yet.'));
          }

          return ListView.builder(
            itemCount: feedbackList.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              final item = feedbackList[index];
              final meta = item['metadata_json'] is Map ? item['metadata_json'] : {};
              final feedbackText = meta['feedback'] ?? item['action'] ?? 'Feedback';
              final email = meta['email'] ?? item['entity_id'] ?? 'Anonymous';
              final timestamp = item['created_at']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: const Icon(Icons.comment, color: Colors.blue),
                  title: Text(feedbackText),
                  subtitle: Text('From: $email\nDate: $timestamp'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
