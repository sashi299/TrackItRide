import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/supabase_service.dart';
import '../../services/notifications_service.dart';
import '../../shared/status_chip.dart';
import '../../shared/theme.dart';

/// Notifications & Announcements Screen matching Figma S23 · Notifications (7:1554)
/// with sub-states S24 (Loading), S25 (Empty), S26 (Offline), S27 (Error).
class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() => _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen> {
  List<Map<String, dynamic>> _localAlerts = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _announcementSub;
  StreamSubscription<List<Map<String, dynamic>>>? _busAlertSub;

  @override
  void initState() {
    super.initState();
    _markNotificationsAsSeen();
    _loadAllNotifications();

    // Listen to real-time bus alerts
    _busAlertSub = NotificationsService.streamBusAlerts().listen((alerts) {
      if (mounted) setState(() => _localAlerts = alerts);
    });

    // Listen to real-time college announcements
    _announcementSub = SupabaseService.streamAnnouncements().listen((items) {
      if (mounted) {
        setState(() {
          _announcements = items;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Announcements realtime error: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _announcementSub?.cancel();
    _busAlertSub?.cancel();
    super.dispose();
  }

  Future<void> _markNotificationsAsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cbts_last_seen_notification_time', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _loadAllNotifications() async {
    try {
      final alerts = await NotificationsService.loadPersistedBusAlerts();
      final ann = await SupabaseService.getAnnouncements();
      if (mounted) {
        setState(() {
          _localAlerts = alerts;
          _announcements = ann;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = <Map<String, dynamic>>[];

    // Add real-time bus alerts first (e.g. proximity, trip start)
    for (final a in _localAlerts) {
      allItems.add({
        ...a,
        'is_bus_alert': true,
      });
    }

    // Add official college announcements
    for (final ann in _announcements) {
      allItems.add({
        ...ann,
        'is_bus_alert': false,
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.muted),
            tooltip: 'Refresh notifications',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAllNotifications();
            },
          ),
        ],
      ),
      body: _isLoading && allItems.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : allItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primarySubtle,
                            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 32,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Live trip starts, stop proximity alerts, and campus transit announcements will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.muted,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _loadAllNotifications,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      final item = allItems[index];
                      final isBusAlert = item['is_bus_alert'] == true;
                      final title = item['title'] ?? 'Notice';
                      final body = item['body'] ?? '';
                      String timeStr = 'Today';
                      if (item['created_at'] != null) {
                        try {
                          final dt = DateTime.parse(item['created_at'].toString()).toLocal();
                          final diff = DateTime.now().difference(dt);
                          if (diff.inMinutes < 1) {
                            timeStr = 'Just now';
                          } else if (diff.inMinutes < 60) {
                            timeStr = '${diff.inMinutes}m ago';
                          } else if (diff.inHours < 24) {
                            timeStr = '${diff.inHours}h ago';
                          } else {
                            timeStr = '${dt.day}/${dt.month}/${dt.year}';
                          }
                        } catch (_) {
                          timeStr = item['created_at'].toString().substring(0, 10);
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                          border: Border.all(
                            color: isBusAlert ? const Color(0xFFFDE68A) : const Color(0xFFF1F5F9),
                            width: isBusAlert ? 1.2 : 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x140F172A),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Tag Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (isBusAlert)
                                  const StatusChip(
                                    label: 'LIVE ALERT',
                                    type: StatusChipType.live,
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primarySubtle,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'CAMPUS ANNOUNCEMENT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                        letterSpacing: 0.5,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.muted,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Title
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Body
                            Text(
                              body,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.muted,
                                fontFamily: 'Inter',
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
