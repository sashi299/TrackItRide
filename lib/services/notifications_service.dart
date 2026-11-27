import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class NotificationsService {
  static final StreamController<List<Map<String, dynamic>>> _busAlertsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static List<Map<String, dynamic>> _inMemoryAlerts = [];
  static const String _kAlertsKey = 'cbts_bus_alerts_history';

  /// Fetch all announcements from Supabase
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    return await SupabaseService.getAnnouncements();
  }

  /// Real-time stream of college announcements
  static Stream<List<Map<String, dynamic>>> streamNotifications() {
    return SupabaseService.streamAnnouncements();
  }

  /// Stream of local / real-time bus alerts
  static Stream<List<Map<String, dynamic>>> streamBusAlerts() {
    return _busAlertsController.stream;
  }

  /// Add a real-time bus alert (trip started, approaching stop)
  static Future<void> addBusAlert({
    required String title,
    required String body,
    required String busCode,
    String? stopName,
  }) async {
    final alert = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'bus_code': busCode,
      'stop_name': stopName,
      'type': 'bus_alert',
      'created_at': DateTime.now().toIso8601String(),
    };

    _inMemoryAlerts.insert(0, alert);
    if (_inMemoryAlerts.length > 30) {
      _inMemoryAlerts = _inMemoryAlerts.sublist(0, 30);
    }
    _busAlertsController.add(List.from(_inMemoryAlerts));

    // Save to SharedPreferences for persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAlertsKey, jsonEncode(_inMemoryAlerts));
    } catch (_) {}
  }

  /// Load persisted bus alerts
  static Future<List<Map<String, dynamic>>> loadPersistedBusAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kAlertsKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(str);
        _inMemoryAlerts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _busAlertsController.add(List.from(_inMemoryAlerts));
        return _inMemoryAlerts;
      }
    } catch (_) {}
    return _inMemoryAlerts;
  }

  /// Post a new announcement (admin only)
  static Future<void> sendNotification({
    required String title,
    required String body,
    String? audienceRole,
  }) async {
    await SupabaseService.postAnnouncement(
      title: title,
      body: body,
      audienceRole: audienceRole,
    );
  }
}
