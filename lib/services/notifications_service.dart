import 'supabase_service.dart';

class NotificationsService {
  /// Fetch all announcements from Supabase
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    return await SupabaseService.getAnnouncements();
  }

  /// Real-time stream of notifications
  static Stream<List<Map<String, dynamic>>> streamNotifications() {
    return SupabaseService.streamAnnouncements();
  }

  /// Post a new notification
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
