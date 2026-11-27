import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

/// All backend access. Requires supabase/001_schema_rls_rpc.sql to be applied.
///
/// Key changes vs the old version:
///  * signIn() REALLY checks the password (old one let anyone in) and can enforce a role
///  * role is decided by the database trigger, never by the client
///  * drivers pick their bus via claim_bus() RPC; GPS goes through post_location() RPC
///  * lists are searched/paginated on the server (500+ buses & routes)
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  // ==========================================
  // AUTH
  // ==========================================

  static User? get currentUser => client.auth.currentUser;
  static String? get currentEmail => client.auth.currentUser?.email;
  static String? get currentUserId => client.auth.currentUser?.id;
  static bool get isSignedIn => client.auth.currentSession != null;

  /// Removes characters that break PostgREST filters / LIKE patterns.
  static String _clean(String q) => q.replaceAll(RegExp(r'[%,()*\\]'), '').trim();

  static Future<void> resendConfirmation({required String email}) async {
    await client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  /// Row from public.users for the logged-in account (role, approved, assigned bus, etc.).
  static Future<Map<String, dynamic>?> getMyProfile() async {
    final uid = currentUserId;
    final email = currentEmail;
    if (uid == null && email == null) return null;

    Map<String, dynamic>? userRow;
    if (uid != null) {
      userRow = await client
          .from('users')
          .select('id, email, name, role, phone, license_number, approved, default_bus_id, route_id, boarding_stop_id')
          .eq('auth_id', uid)
          .maybeSingle();
    }
    if (userRow == null && email != null) {
      userRow = await client
          .from('users')
          .select('id, email, name, role, phone, license_number, approved, default_bus_id, route_id, boarding_stop_id')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      if (userRow != null && uid != null) {
        // Automatically sync auth_id for existing rows
        try {
          await client.from('users').update({'auth_id': uid}).eq('id', userRow['id']);
        } catch (_) {}
      }
    }
    return userRow;
  }

  /// Comprehensive commuter profile (for student & faculty) including assigned bus details,
  /// route name, and boarding stop coordinates.
  static Future<Map<String, dynamic>?> getMyCommuterProfile() async {
    final user = await getMyProfile();
    if (user == null) return null;

    final profile = Map<String, dynamic>.from(user);

    // Fetch bus details if assigned
    final busId = user['default_bus_id'];
    if (busId != null) {
      try {
        final bus = await client
            .from('buses')
            .select('id, code, label, default_route_id')
            .eq('id', busId)
            .maybeSingle();
        if (bus != null) {
          profile['bus_code'] = bus['code'];
          profile['bus_label'] = bus['label'];
          if (profile['route_id'] == null && bus['default_route_id'] != null) {
            profile['route_id'] = bus['default_route_id'];
          }
        }
      } catch (e) {
        debugPrint('Error fetching assigned bus: $e');
      }
    }

    // Fetch route details if assigned
    final routeId = profile['route_id'];
    if (routeId != null) {
      try {
        final route = await client
            .from('routes')
            .select('id, code, name')
            .eq('id', routeId)
            .maybeSingle();
        if (route != null) {
          profile['route_code'] = route['code'];
          profile['route_name'] = route['name'];
        }
      } catch (e) {
        debugPrint('Error fetching assigned route: $e');
      }
    }

    // Fetch stop details if assigned
    final stopId = user['boarding_stop_id'];
    if (stopId != null) {
      try {
        final stop = await client
            .from('stops')
            .select('id, name, latitude, longitude, sequence_no')
            .eq('id', stopId)
            .maybeSingle();
        if (stop != null) {
          profile['stop_name'] = stop['name'];
          profile['stop_latitude'] = (stop['latitude'] as num?)?.toDouble();
          profile['stop_longitude'] = (stop['longitude'] as num?)?.toDouble();
          profile['stop_sequence'] = stop['sequence_no'];
        }
      } catch (e) {
        debugPrint('Error fetching assigned stop: $e');
      }
    }

    return profile;
  }

  /// Update student or faculty commuter profile (bus, route, boarding stop, name, phone, role)
  static Future<void> updateCommuterProfile({
    String? busId,
    String? routeId,
    String? stopId,
    String? role,
    String? name,
    String? phone,
  }) async {
    final uid = currentUserId;
    final email = currentEmail;
    if (uid == null && email == null) throw Exception('User not logged in');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (busId != null) updates['default_bus_id'] = busId;
    if (routeId != null) updates['route_id'] = routeId;
    if (stopId != null) updates['boarding_stop_id'] = stopId;
    if (role != null) updates['role'] = role;
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;

    var query = client.from('users').update(updates);
    if (uid != null) {
      await query.eq('auth_id', uid);
    } else {
      await query.eq('email', email!.toLowerCase().trim());
    }
  }

  /// Search buses by bus number / code / label with fallback
  static Future<List<Map<String, dynamic>>> findBusesByQuery(String query) async {
    final q = query.trim().toLowerCase();
    try {
      if (q.isEmpty) {
        final res = await client
            .from('buses')
            .select('id, code, label, default_route_id, active')
            .eq('active', true)
            .order('code')
            .limit(20);
        return List<Map<String, dynamic>>.from(res);
      }
      final res = await client
          .from('buses')
          .select('id, code, label, default_route_id, active')
          .eq('active', true)
          .or('code.ilike.%$q%,label.ilike.%$q%')
          .order('code')
          .limit(20);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('findBusesByQuery error: $e');
      return [];
    }
  }

  /// Get user role for RouteGuard & backward compatibility
  static Future<String> getUserRole([String? email]) async {
    final profile = await getMyProfile();
    if (profile != null && profile['role'] != null) {
      return profile['role'] as String;
    }
    final targetEmail = email ?? currentEmail;
    if (targetEmail != null) {
      final res = await client
          .from('users')
          .select('role')
          .eq('email', targetEmail.toLowerCase().trim())
          .maybeSingle();
      if (res != null && res['role'] != null) {
        return res['role'] as String;
      }
    }
    return 'student';
  }

  /// Throws on wrong password / unconfirmed email / wrong role.
  /// Pass requiredRole: 'driver' | 'student' | 'admin' from the matching login screen.
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
    String? requiredRole,
  }) async {
    final res = await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
    if (res.session == null) {
      throw const AuthException('Login failed. Please try again.');
    }
    if (requiredRole != null) {
      final profile = await getMyProfile();
      if (profile == null || profile['role'] != requiredRole) {
        await client.auth.signOut();
        throw AuthException('This account is not registered as $requiredRole.');
      }
    }
    return res;
  }

  /// role is only a REQUEST: the DB trigger allows 'driver' or 'student'
  /// (anything else becomes 'student'). Drivers stay unapproved until an admin approves.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String role,
    String? name,
    String? phone,
    String? licenseNumber,
  }) {
    return client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password.trim(),
      data: {
        'role': role,
        'name': name ?? '',
        'phone': phone ?? '',
        'license': licenseNumber ?? '',
      },
    );
  }

  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('signOut: $e');
    }
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  // ==========================================
  // BUSES (admin)
  // ==========================================

  /// Paged + searchable. Default pageSize is PostgREST's 1000 cap for old callers;
  /// UI lists should pass pageSize: 30-50 and a query.
  static Future<List<Map<String, dynamic>>> getBuses({
    String query = '',
    int page = 0,
    int pageSize = 1000,
  }) async {
    var f = client
        .from('buses')
        .select('id, code, label, capacity, active, assigned_driver_id, default_route_id');
    final q = _clean(query);
    if (q.isNotEmpty) f = f.ilike('code', '$q%');
    final res = await f.order('code').range(page * pageSize, page * pageSize + pageSize - 1);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> addBus({
    required String busNumber,
    required String numberPlate,
    int capacity = 40,
    String? routeId,
  }) async {
    try {
      await client.from('buses').insert({
        'code': busNumber.trim(),
        'label': numberPlate.trim().isNotEmpty ? numberPlate.trim() : 'Bus $busNumber',
        'capacity': capacity,
        'active': true,
        if (routeId != null) 'default_route_id': routeId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('Bus number ${busNumber.trim()} already exists');
      rethrow;
    }
  }

  static Future<void> updateBus({
    required String busId,
    required String busNumber,
    required String numberPlate,
    String? routeId,
    int? capacity,
    bool? active,
  }) async {
    try {
      await client.from('buses').update({
        'code': busNumber.trim(),
        'label': numberPlate.trim(),
        if (routeId != null) 'default_route_id': routeId,
        if (capacity != null) 'capacity': capacity,
        if (active != null) 'active': active,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', busId);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('Bus number ${busNumber.trim()} already exists');
      rethrow;
    }
  }

  static Future<void> deleteBus(String busId) async {
    await client.from('buses').delete().eq('id', busId);
  }

  // ==========================================
  // DRIVERS (admin)
  // ==========================================

  static Future<List<Map<String, dynamic>>> getDrivers({
    String query = '',
    int page = 0,
    int pageSize = 1000,
  }) async {
    var f = client
        .from('users')
        .select('id, name, email, phone, license_number, approved, active')
        .eq('role', 'driver');
    final q = _clean(query);
    if (q.isNotEmpty) f = f.or('name.ilike.%$q%,email.ilike.%$q%,phone.ilike.%$q%');
    final res = await f.order('name').range(page * pageSize, page * pageSize + pageSize - 1);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Admin creates a driver WITHOUT logging the admin out (uses a throw-away client)
  /// and marks the driver approved.
  /// TODO (proper): move to a Supabase Edge Function using the service-role key.
  static Future<void> registerDriver({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? licenseNumber,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final temp = SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await temp.auth.signUp(
        email: cleanEmail,
        password: password.trim(),
        data: {'role': 'driver', 'name': name, 'phone': phone ?? '', 'license': licenseNumber ?? ''},
      );
    } finally {
      await temp.dispose();
    }
    await setDriverApproved(email: cleanEmail, approved: true);
  }

  static Future<void> setDriverApproved({required String email, required bool approved}) async {
    await client.from('users').update({'approved': approved}).eq('email', email.trim().toLowerCase());
  }

  static Future<void> updateDriver({
    required String driverId,
    required String name,
    required String email,
    String? phone,
    String? licenseNumber,
  }) async {
    await client.from('users').update({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      if (phone != null) 'phone': phone.trim(),
      if (licenseNumber != null) 'license_number': licenseNumber.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', driverId);
  }

  static Future<void> deleteDriver(String driverId) async {
    await client.from('users').delete().eq('id', driverId);
  }

  // ==========================================
  // HIGH-CONCURRENCY (10,000+ USERS) MEMORY CACHING
  // ==========================================
  static List<Map<String, dynamic>>? _cachedRoutes;
  static DateTime? _routesCacheTime;
  static final Map<String, List<Map<String, dynamic>>> _cachedStops = {};
  static List<Map<String, dynamic>>? _cachedDefaultBuses;
  static DateTime? _defaultBusesCacheTime;

  static void invalidateCaches() {
    _cachedRoutes = null;
    _routesCacheTime = null;
    _cachedStops.clear();
    _cachedDefaultBuses = null;
    _defaultBusesCacheTime = null;
  }

  // ==========================================
  // ROUTES & STOPS
  // ==========================================

  static Future<List<Map<String, dynamic>>> getRoutes({
    String query = '',
    int page = 0,
    int pageSize = 1000,
  }) async {
    final q = _clean(query);
    if (q.isEmpty && page == 0 && _cachedRoutes != null && _routesCacheTime != null) {
      if (DateTime.now().difference(_routesCacheTime!) < const Duration(minutes: 5)) {
        return _cachedRoutes!;
      }
    }

    var f = client.from('routes').select('*').eq('active', true);
    if (q.isNotEmpty) f = f.or('name.ilike.%$q%,code.ilike.%$q%');
    final res = await f.order('name').range(page * pageSize, page * pageSize + pageSize - 1);
    final list = List<Map<String, dynamic>>.from(res);
    if (q.isEmpty && page == 0) {
      _cachedRoutes = list;
      _routesCacheTime = DateTime.now();
    }
    return list;
  }

  /// Student search: route name/code OR any stop name. Server-side, max [limit] routes.
  static Future<List<Map<String, dynamic>>> searchRoutes(String query, {int limit = 30}) async {
    final q = _clean(query);
    if (q.isEmpty) return getRoutes(pageSize: limit);

    final byRoute = await client
        .from('routes')
        .select('*')
        .eq('active', true)
        .or('name.ilike.%$q%,code.ilike.%$q%')
        .limit(limit);
    final byStop = await client.from('stops').select('route_id').ilike('name', '%$q%').limit(60);

    final found = <String, Map<String, dynamic>>{
      for (final r in List<Map<String, dynamic>>.from(byRoute)) r['id'] as String: r,
    };
    final extraIds = {
      for (final s in List<Map<String, dynamic>>.from(byStop)) s['route_id'] as String
    }..removeAll(found.keys);

    if (extraIds.isNotEmpty && found.length < limit) {
      final more = await client
          .from('routes')
          .select('*')
          .eq('active', true)
          .inFilter('id', extraIds.take(limit - found.length).toList());
      for (final r in List<Map<String, dynamic>>.from(more)) {
        found[r['id'] as String] = r;
      }
    }
    return found.values.toList();
  }

  static Future<List<Map<String, dynamic>>> getStopsForRoute(String routeId) async {
    if (_cachedStops.containsKey(routeId)) {
      return _cachedStops[routeId]!;
    }
    final res = await client
        .from('stops')
        .select('*')
        .eq('route_id', routeId)
        .order('sequence_no', ascending: true);
    final list = List<Map<String, dynamic>>.from(res);
    _cachedStops[routeId] = list;
    return list;
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
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', routeId);
  }

  static Future<void> deleteRoute(String routeId) async {
    await client.from('routes').delete().eq('id', routeId);
  }

  static Future<List<Map<String, dynamic>>> getStops(String routeId) => getStopsForRoute(routeId);

  static Future<void> addStop({
    required String routeId,
    required String name,
    required int sequenceNo,
    required double latitude,
    required double longitude,
    String? scheduledMorning,
    String? scheduledEvening,
  }) async {
    _cachedStops.remove(routeId);
    await client.from('stops').insert({
      'route_id': routeId,
      'name': name.trim(),
      'sequence_no': sequenceNo,
      'latitude': latitude,
      'longitude': longitude,
      if (scheduledMorning != null) 'scheduled_morning': scheduledMorning.trim(),
      if (scheduledEvening != null) 'scheduled_evening': scheduledEvening.trim(),
      'active': true,
    });
  }

  static Future<void> deleteStop(String stopId) async {
    _cachedStops.clear();
    await client.from('stops').delete().eq('id', stopId);
  }

  // ==========================================
  // DRIVER: choose bus -> run trip -> stream GPS
  // ==========================================

  /// Server-side search by bus number (prefix) or plate/label (contains).
  /// Used by BOTH the driver "select bus" screen and the student bus search.
  static Future<List<Map<String, dynamic>>> searchBuses(
    String query, {
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await client.rpc('search_buses', params: {
      'p_query': _clean(query),
      'p_limit': limit,
      'p_offset': offset,
    });
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Driver picks their bus by number. Throws a readable Exception on failure.
  static Future<Map<String, dynamic>> claimBus(String busCode) async {
    try {
      final res = await client.rpc('claim_bus', params: {'p_bus_code': busCode.trim()});
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Driver registers their bus and route on the fly and claims it.
  static Future<Map<String, dynamic>> driverRegisterAndClaimBus({
    required String busCode,
    String? plate,
    String? routeId,
  }) async {
    try {
      final res = await client.rpc('driver_register_and_claim_bus', params: {
        'p_bus_code': busCode.trim(),
        'p_plate': plate?.trim() ?? '',
        'p_route_id': routeId,
      });
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  static Future<void> releaseBus() async {
    await client.rpc('release_bus');
  }

  /// null => driver has not selected a bus yet.
  /// (email param kept only so old call sites still compile; identity comes from the session.)
  static Future<Map<String, dynamic>?> getDriverAssignment([String? _]) async {
    final res = await client.rpc('my_assignment');
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> startTrip() async {
    try {
      final res = await client.rpc('start_trip');
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  static Future<void> endTrip() async {
    await client.rpc('end_trip');
  }

  static Future<void> setTripDestination(String destinationName) async {
    try {
      final assignment = await getDriverAssignment();
      final busId = assignment?['busId'] ?? assignment?['bus_id'];
      if (busId != null) {
        await client
            .from('trips')
            .update({'direction': destinationName.trim()})
            .eq('bus_id', busId)
            .eq('status', 'running');
      }
    } catch (e) {
      debugPrint('setTripDestination failed: $e');
    }
  }

  static Future<void> postLocation({
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) async {
    await client.rpc('post_location', params: {
      'p_lat': latitude,
      'p_lng': longitude,
      'p_speed': speed ?? 0,
      'p_heading': heading ?? 0,
    });
  }

  /// DRIVER: 1-Tap Emergency / Breakdown SOS Broadcast
  /// Updates bus_live status to issueType ('breakdown', 'delayed', 'traffic_jam')
  /// and broadcasts an urgent announcement to commuters and fleet managers.
  static Future<void> reportTripIssue({
    required String busId,
    required String issueType,
    String? note,
    String? busCode,
  }) async {
    try {
      // 1. Update bus_live status
      await client
          .from('bus_live')
          .update({
            'status': issueType,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('bus_id', busId);

      // 2. Also update active trip in trips table if present
      await client
          .from('trips')
          .update({
            'status': issueType,
          })
          .eq('bus_id', busId)
          .eq('status', 'running');

      // 3. Post urgent alert announcement for commuters
      final label = issueType == 'breakdown'
          ? 'Mechanical Breakdown'
          : issueType == 'traffic_jam'
              ? 'Severe Traffic Jam'
              : 'Trip Delay Alert';

      final codePrefix = (busCode != null && busCode.isNotEmpty) ? 'Bus $busCode' : 'College Bus';
      final title = '⚠️ $codePrefix Alert: $label';
      final body = note != null && note.isNotEmpty
          ? note
          : '$codePrefix reported $label. Transport administration has been notified.';

      await postAnnouncement(
        title: title,
        body: body,
        audienceRole: 'student',
      );
    } catch (e) {
      debugPrint('reportTripIssue error: $e');
      rethrow;
    }
  }

  // ==========================================
  // STUDENT / ADMIN: bus lists + live position
  // ==========================================

  /// Same keys as the old method so existing screens keep working, but now
  /// searched + limited on the server (never all 500 buses).
  static Future<List<Map<String, dynamic>>> getAssignedBuses({
    String query = '',
    int limit = 30,
  }) async {
    final q = query.trim();
    if (q.isEmpty && _cachedDefaultBuses != null && _defaultBusesCacheTime != null) {
      if (DateTime.now().difference(_defaultBusesCacheTime!) < const Duration(seconds: 30)) {
        return _cachedDefaultBuses!;
      }
    }
    final rows = await searchBuses(query, limit: limit);
    final list = rows
        .map((r) => {
              'busId': r['bus_id'],
              'busNumber': r['code'] ?? 'N/A',
              'numberPlate': r['label'] ?? '',
              'driverName': r['driver_name'] ?? 'Unassigned',
              'driverEmail': '',
              'routeId': r['route_id'],
              'routeName': r['route_name'] ?? 'No route',
              'routeCode': r['route_code'] ?? '',
              'tripId': r['trip_id'],
              'status': r['status'] ?? 'idle',
            })
        .toList();
    if (q.isEmpty) {
      _cachedDefaultBuses = list;
      _defaultBusesCacheTime = DateTime.now();
    }
    return list;
  }

  /// ADMIN: bus -> driver + route. Replaces the old client-side trips.upsert (which created duplicates).
  static Future<void> assignBus({
    required String busId,
    required String driverId,
    required String routeId,
  }) async {
    await client.rpc('admin_assign_bus', params: {
      'p_bus_id': busId,
      'p_driver_id': driverId,
      'p_route_id': routeId,
    });
  }

  static Future<void> adminReleaseBus(String busId) async {
    await client.rpc('admin_release_bus', params: {'p_bus_id': busId});
  }

  /// ONE row per bus -> cheap realtime. Emits null until the bus has ever gone live.
  static Stream<Map<String, dynamic>?> streamBusLive(String busId) {
    return client
        .from('bus_live')
        .stream(primaryKey: ['bus_id'])
        .eq('bus_id', busId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Direct REST read of current live telemetry for a specific bus
  static Future<Map<String, dynamic>?> getBusLive(String busId) async {
    try {
      final res = await client
          .from('bus_live')
          .select('*')
          .eq('bus_id', busId)
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      debugPrint('getBusLive failed: $e');
      return null;
    }
  }

  /// Realtime stream of the entire active fleet's live coordinates and status
  static Stream<List<Map<String, dynamic>>> streamAllLiveBuses() {
    return client
        .from('bus_live')
        .stream(primaryKey: ['bus_id']);
  }

  /// Fetches all registered buses merged with their latest live telemetry from bus_live
  static Future<List<Map<String, dynamic>>> getFleetWithLiveLocations() async {
    final buses = await getBuses();
    try {
      final liveRows = await client.from('bus_live').select('*');
      final liveMap = <String, Map<String, dynamic>>{};
      for (final row in liveRows) {
        if (row['bus_id'] != null) {
          liveMap[row['bus_id'].toString()] = Map<String, dynamic>.from(row);
        }
      }
      return buses.map((b) {
        final busId = b['id']?.toString() ?? '';
        final live = liveMap[busId];
        final map = Map<String, dynamic>.from(b);
        map['latitude'] = (live?['latitude'] as num?)?.toDouble();
        map['longitude'] = (live?['longitude'] as num?)?.toDouble();
        map['speed_mps'] = (live?['speed_mps'] as num?)?.toDouble();
        map['heading'] = (live?['heading'] as num?)?.toDouble();
        map['status'] = live?['status'] ?? 'idle';
        map['updated_at'] = live?['updated_at'];
        return map;
      }).toList();
    } catch (e) {
      debugPrint('getFleetWithLiveLocations error: $e');
      return buses;
    }
  }

  // ==========================================
  // ANNOUNCEMENTS
  // ==========================================

  static Future<List<Map<String, dynamic>>> getAnnouncements({int limit = 50}) async {
    final res = await client
        .from('announcements')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  static Stream<List<Map<String, dynamic>>> streamAnnouncements() {
    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50);
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

  static Future<void> createAnnouncement({
    required String title,
    required String message,
    String? audienceRole,
  }) => postAnnouncement(title: title, body: message, audienceRole: audienceRole);

  // ==========================================
  // FEEDBACK (admin-read only; see RLS)
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
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      },
    });
  }

  static Future<List<Map<String, dynamic>>> getFeedbacks({int limit = 100}) async {
    final res = await client
        .from('audit_logs')
        .select('*')
        .eq('entity_type', 'feedback')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }
}
