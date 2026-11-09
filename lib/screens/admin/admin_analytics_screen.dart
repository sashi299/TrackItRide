import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isPosting = false;

  Map<String, int> counts = {'buses': 0, 'drivers': 0, 'routes': 0};

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final buses = await SupabaseService.getBuses();
      final drivers = await SupabaseService.getDrivers();
      final routes = await SupabaseService.getRoutes();
      if (mounted) {
        setState(() {
          counts = {
            'buses': buses.length,
            'drivers': drivers.length,
            'routes': routes.length,
          };
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _postAnnouncement() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter announcement title and body.')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      await SupabaseService.postAnnouncement(title: title, body: body);
      _titleController.clear();
      _bodyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement broadcasted via Supabase!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Analytics & Broadcast")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Fleet Metrics (Live from Supabase)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _metricCard("Buses", counts['buses'] ?? 0, Colors.blue),
                _metricCard("Drivers", counts['drivers'] ?? 0, Colors.green),
                _metricCard("Routes", counts['routes'] ?? 0, Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            const Text("Broadcast Announcement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Send instant notification to all student and driver apps:"),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message Body', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            _isPosting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Broadcast Announcement'),
                    onPressed: _postAnnouncement,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, int value, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
