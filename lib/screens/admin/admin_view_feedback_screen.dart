import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';

class AdminViewFeedbackScreen extends StatefulWidget {
  const AdminViewFeedbackScreen({super.key});

  @override
  State<AdminViewFeedbackScreen> createState() => _AdminViewFeedbackScreenState();
}

class _AdminViewFeedbackScreenState extends State<AdminViewFeedbackScreen> {
  late Future<List<Map<String, dynamic>>> _feedbacksFuture;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  void _loadFeedback() {
    setState(() {
      _feedbacksFuture = SupabaseService.getFeedbacks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Feedback (Supabase)'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFeedback),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _feedbacksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedbackList = snapshot.data ?? [];
          if (feedbackList.isEmpty) {
            return const Center(child: Text('No feedback recorded yet in Supabase.'));
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
                  leading: const Icon(Icons.rate_review, color: Colors.blue),
                  title: Text(feedbackText),
                  subtitle: Text('From: $email\nSubmitted: $timestamp'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
