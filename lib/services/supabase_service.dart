import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase client
  static Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  // ==========================================
  // AUTHENTICATION
  // ==========================================

  static User? get currentUser => client.auth.currentUser;
  static String? get currentEmail => client.auth.currentUser?.email;
  static String? get currentUserId => client.auth.currentUser?.id;

  /// Resend confirmation email
  static Future<void> resendConfirmation({required String email}) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  /// Sign In with Email and Password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Sign Up with Email, Password, and Role
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String role,
    String? name,
    String? phone,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password.trim(),
      data: {
        'role': role,
        'name': name ?? '',
        'phone': phone ?? '',
      },
    );

    // Auto-record user in public.users table
    try {
      await client.from('users').upsert({
        'email': email.trim().toLowerCase(),
        'name': (name != null && name.isNotEmpty) ? name : email.split('@').first,
        'external_id': email.trim().toLowerCase(),
        'role': role,
        'active': true,
      }, onConflict: 'email');
    } catch (e) {
      // Best-effort user sync
    }

    return response;
  }

  /// Sign Out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Reset Password via Email
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  // ==========================================
  // BUSES MANAGEMENT
  // ==========================================

  static Future<List<Map<String, dynamic>>> getBuses() async {
    final res = await client.from('buses').select('*').order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> addBus({
    required String busNumber,
    required String numberPlate,
    int capacity = 40,
  }) async {
    await client.from('buses').insert({
      'code': busNumber.trim(),
      'label': numberPlate.trim().isNotEmpty ? numberPlate.trim() : 'Bus $busNumber',
      'capacity': capacity,
      'active': true,
    });
  }

  static Future<void> updateBus({
    required String busId,
    required String busNumber,
    required String numberPlate,
  }) async {
    await client.from('buses').update({
      'code': busNumber.trim(),
      'label': numberPlate.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', busId);
  }

  static Future<void> deleteBus(String busId) async {
    await client.from('buses').delete().eq('id', busId);
  }

  // ==========================================
  // DRIVERS MANAGEMENT
  // ==========================================

  static Future<List<Map<String, dynamic>>> getDrivers() async {
    final res = await client.from('users').select('*').eq('role', 'driver').order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> registerDriver({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    // 1. Sign up auth account
    await signUp(
      email: email,
      password: password,
      role: 'driver',
      name: name,
      phone: phone,
    );
  }

  static Future<void> updateDriver({
    required String driverId,
    required String name,
    required String email,
  }) async {
    await client.from('users').update({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', driverId);
  }

  static Future<void> deleteDriver(String driverId) async {
    await client.from('users').delete().eq('id', driverId);
  }

  // ==========================================
  // ROUTES & STOPS MANAGEMENT
  // ==========================================

  static Future<List<Map<String, dynamic>>> getRoutes() async {
    final res = await client.from('routes').select('*').eq('active', true).order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getStopsForRoute(String routeId) async {
    final res = await client
        .from('stops')
        .select('*')
        .eq('route_id', routeId)
        .order('sequence_no', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> addRoute({
    required String routeName,
    required String routeCode,
    String color = '#32D3A5',
  }) async {
    await client.from('routes').insert({
      'name': routeName.trim(),
      'code': routeCode.trim(),
      'color': color,
      'active': true,
    });
  }

  static Future<void> updateRoute({
    required String routeId,
    required String routeName,
    required String routeCode,
  }) async {
    await client.from('routes').update({
      'name': routeName.trim(),
      'code': routeCode.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', routeId);
  }

  static Future<void> deleteRoute(String routeId) async {
    await client.from('routes').delete().eq('id', routeId);
  }

  static Future<void> addStop({
    required String routeId,
    required String name,
    required int sequenceNo,
    required double latitude,
    required double longitude,
  }) async {
    await client.from('stops').insert({
      'route_id': routeId,
      'name': name.trim(),
      'sequence_no': sequenceNo,
      'latitude': latitude,
      'longitude': longitude,
      'active': true,
    });
  }

  // ==========================================
  // BUS ASSIGNMENT & ACTIVE TRIPS
  // ==========================================

  static Future<Map<String, dynamic>?> getDriverAssignment(String driverEmail) async {
    final userRes = await client
        .from('users')
        .select('id, name, email')
        .eq('email', driverEmail.trim().toLowerCase())
        .maybeSingle();

    if (userRes == null) return null;
    final driverId = userRes['id'];

    final busRes = await client
        .from('buses')
        .select('id, code, label, assigned_driver_id')
        .eq('assigned_driver_id', driverId)
        .maybeSingle();

    if (busRes == null) return null;

    final tripRes = await client
        .from('trips')
        .select('id, bus_id, route_id, driver_id, status, routes(name, code)')
        .eq('bus_id', busRes['id'])
        .inFilter('status', ['running', 'scheduled', 'delayed'])
        .maybeSingle();

    return {
      'busId': busRes['id'],
      'busNumber': busRes['code'],
      'numberPlate': busRes['label'],
      'driverEmail': driverEmail,
      'driverId': driverId,
      'tripId': tripRes?['id'],
      'routeId': tripRes?['route_id'],
      'routeName': tripRes?['routes']?['name'] ?? 'Assigned Route',
      'routeCode': tripRes?['routes']?['code'] ?? 'R1',
    };
  }

  static Future<List<Map<String, dynamic>>> getAssignedBuses() async {
    final buses = await client.from('buses').select('*, users(*)');
    final trips = await client.from('trips').select('*, routes(*)').inFilter('status', ['running', 'scheduled', 'delayed']);

    List<Map<String, dynamic>> result = [];
    for (var bus in buses) {
      final tripMatches = trips.where((t) => t['bus_id'] == bus['id']).toList();
      final Map<String, dynamic>? trip = tripMatches.isNotEmpty ? tripMatches.first : null;

      result.add({
        'busId': bus['id'],
        'busNumber': bus['code'] ?? 'N/A',
        'numberPlate': bus['label'] ?? '',
        'driverName': bus['users']?['name'] ?? 'Unassigned',
        'driverEmail': bus['users']?['email'] ?? '',
        'routeName': trip?['routes']?['name'] ?? 'Campus Route',
        'routeCode': trip?['routes']?['code'] ?? 'R1',
        'tripId': trip?['id'],
        'status': trip?['status'] ?? 'idle',
      });
    }
    return result;
  }

  static Future<void> assignBus({
    required String busId,
    required String driverId,
    required String routeId,
  }) async {
    await client.from('buses').update({
      'assigned_driver_id': driverId,
    }).eq('id', busId);

    // Create or update active trip
    await client.from('trips').upsert({
      'bus_id': busId,
      'route_id': routeId,
      'driver_id': driverId,
      'status': 'scheduled',
      'direction': 'morning',
    });
  }

  // ==========================================
  // REAL-TIME GPS TRACKING
  // ==========================================

  static Future<void> updateLocation({
    required String tripId,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Insert into trip_locations
    await client.from('trip_locations').insert({
      'trip_id': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'speed_mps': speed ?? 0.0,
      'captured_at': now,
    });

    // 2. Update trip summary
    await client.from('trips').update({
      'last_latitude': latitude,
      'last_longitude': longitude,
      'last_speed_mps': speed ?? 0.0,
      'last_location_at': now,
      'status': 'running',
      'updated_at': now,
    }).eq('id', tripId);
  }

  /// Real-time stream of all active trips (for Student and Fleet Map)
  static Stream<List<Map<String, dynamic>>> streamActiveTrips() {
    return client
        .from('trips')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false);
  }

  /// Real-time stream of locations for a specific trip
  static Stream<List<Map<String, dynamic>>> streamTripLocations(String tripId) {
    return client
        .from('trip_locations')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('captured_at', ascending: true);
  }

  // ==========================================
  // ANNOUNCEMENTS & NOTIFICATIONS
  // ==========================================

  static Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final res = await client
        .from('announcements')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Stream<List<Map<String, dynamic>>> streamAnnouncements() {
    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  static Future<void> postAnnouncement({
    required String title,
    required String body,
    String? audienceRole,
  }) async {
    await client.from('announcements').insert({
      'title': title.trim(),
      'body': body.trim(),
      'audience_role': audienceRole,
      'created_by': currentEmail ?? 'Admin',
    });
  }

  // ==========================================
  // FEEDBACK
  // ==========================================

  static Future<void> submitFeedback({
    required String feedback,
    required String email,
  }) async {
    await client.from('audit_logs').insert({
      'action': 'FEEDBACK_SUBMITTED',
      'entity_type': 'feedback',
      'entity_id': email,
      'metadata_json': {
        'feedback': feedback,
        'email': email,
        'submitted_at': DateTime.now().toIso8601String(),
      },
    });
  }

  static Future<List<Map<String, dynamic>>> getFeedbacks() async {
    final res = await client
        .from('audit_logs')
        .select('*')
        .eq('entity_type', 'feedback')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }
}
