import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'tracking_interpolator.dart';

/// Professional Real-Time GPS Tracking Service for Driver Operations.
/// Upgraded to continuous telemetry with adaptive transmission, accuracy filtering,
/// bearing calculation, offline breadcrumb FIFO queuing, and background persistence.
class GpsTrackingService {
  static StreamSubscription<Position>? _sub;
  static Timer? _heartbeat;
  static Position? _last;
  static LatLng? _lastSentLatLng;
  static DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _isTracking = false;
  static bool _sending = false;

  // Offline FIFO breadcrumb queue (cellular network drop resilience)
  static const String _kOfflineQueueKey = 'trackitride_offline_breadcrumbs';
  static const int _kMaxQueueSize = 250;
  static final List<Map<String, dynamic>> _offlineBreadcrumbs = [];
  static bool _isFlushingQueue = false;

  static int get offlineQueueLength => _offlineBreadcrumbs.length;

  /// Dynamic update intervals:
  /// - Active movement: send updates every 2 seconds or every 5 meters moved.
  /// - Stationary / Bus stop: throttle writes to 10-second heartbeat to save DB IOPS.
  static const Duration activeInterval = Duration(milliseconds: 2000);
  static const Duration heartbeatEvery = Duration(seconds: 10);

  static bool get isTracking => _isTracking;

  static Future<bool> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
      return false;
    }

    // On Android, request notification and ignoreBatteryOptimizations so tracking survives app backgrounding
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
        if (await Permission.ignoreBatteryOptimizations.isDenied) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (e) {
        debugPrint('Battery/Notification permission request: $e');
      }
    }

    return true;
  }

  static LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // 3m sensitivity for smooth turns
        intervalDuration: const Duration(seconds: 2), // 2s continuous telemetry
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'TrackItRide - Trip in Progress',
          notificationText: 'Broadcasting live vehicle telemetry to students',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );
  }

  /// Call AFTER SupabaseService.startTrip() succeeded (post_location requires a running trip).
  static Future<bool> startTracking({
    void Function(Position)? onLocationUpdate,
    void Function(Object error)? onError,
  }) async {
    if (!await checkPermission()) return false;
    await stopTracking();
    _isTracking = true;

    // Load any persisted offline breadcrumbs from prior network outages
    await _loadQueueFromPrefs();

    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
      (pos) {
        // 1. Accuracy Filter: discard noisy GPS readings
        if (!TrackingInterpolator.isValidGpsUpdate(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          timestamp: pos.timestamp,
        )) {
          debugPrint('Ignored noisy GPS reading (accuracy: ${pos.accuracy}m)');
          return;
        }

        // 2. Reject impossible jumps
        if (_last != null) {
          final isJump = TrackingInterpolator.isImpossibleJump(
            previousPos: LatLng(_last!.latitude, _last!.longitude),
            previousTime: _last!.timestamp,
            newPos: LatLng(pos.latitude, pos.longitude),
            newTime: pos.timestamp,
          );
          if (isJump) {
            debugPrint('Rejected impossible GPS jump (>144 km/h)');
            return;
          }
        }

        _last = pos;
        onLocationUpdate?.call(pos);
        _maybeSend(onError: onError);
      },
      onError: (Object err) {
        debugPrint('Geolocator stream error: $err');
        onError?.call(err);
      },
      cancelOnError: false,
    );

    // Heartbeat ensures students know the bus is alive even when stationary at a traffic stop
    _heartbeat = Timer.periodic(heartbeatEvery, (_) {
      if (_last != null && DateTime.now().difference(_lastSent) >= heartbeatEvery) {
        _maybeSend(onError: onError, force: true);
      }
    });

    // Immediately attempt to acquire and publish initial fix without waiting for stream tick
    try {
      final initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      if (_isTracking && _last == null) {
        _last = initial;
        onLocationUpdate?.call(initial);
        await _maybeSend(onError: onError, force: true);
      }
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (_isTracking && _last == null && lastKnown != null) {
          _last = lastKnown;
          onLocationUpdate?.call(lastKnown);
          await _maybeSend(onError: onError, force: true);
        }
      } catch (_) {}
    }

    return true;
  }

  /// Manually dispatches a known valid coordinate immediately to Supabase
  static Future<void> sendManualLocation({
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) async {
    _lastSentLatLng = LatLng(latitude, longitude);
    _lastSent = DateTime.now();
    await SupabaseService.postLocation(
      latitude: latitude,
      longitude: longitude,
      speed: speed ?? 0,
      heading: heading ?? 0,
    );
  }

  static Future<void> _maybeSend({
    void Function(Object error)? onError,
    bool force = false,
  }) async {
    final pos = _last;
    if (pos == null || _sending) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSent);
    final currentLatLng = LatLng(pos.latitude, pos.longitude);

    // Distance moved since last sent update
    double distanceMoved = 0.0;
    if (_lastSentLatLng != null) {
      distanceMoved = TrackingInterpolator.distanceMeters(_lastSentLatLng!, currentLatLng);
    }

    final isStationary = TrackingInterpolator.isStationary(
      displacementMeters: distanceMoved,
      speedMps: pos.speed,
    );

    // Throttling Logic:
    // If stationary and not forced, only send every heartbeatEvery (10s)
    if (!force) {
      if (isStationary && elapsed < heartbeatEvery) {
        return;
      }
      if (!isStationary && elapsed < activeInterval && distanceMoved < 6.0) {
        return;
      }
    }

    // Resolve heading: use hardware heading or compute bearing from last position
    double heading = pos.heading;
    if ((heading <= 0.0 || heading.isNaN) && _lastSentLatLng != null && distanceMoved > 2.5) {
      heading = TrackingInterpolator.calculateBearing(_lastSentLatLng!, currentLatLng);
    }

    _sending = true;
    try {
      await SupabaseService.postLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speed: pos.speed,
        heading: heading,
      );
      _lastSent = now;
      _lastSentLatLng = currentLatLng;

      // Online network active: flush any pending offline breadcrumbs
      if (_offlineBreadcrumbs.isNotEmpty) {
        _flushOfflineQueue();
      }
    } catch (e) {
      debugPrint('post_location failed (network drop): $e. Buffering breadcrumb.');
      _queueOfflineBreadcrumb({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': pos.speed,
        'heading': heading,
        'timestamp': now.toIso8601String(),
      });
      onError?.call(e);
    } finally {
      _sending = false;
    }
  }

  static void _queueOfflineBreadcrumb(Map<String, dynamic> item) {
    if (_offlineBreadcrumbs.length >= _kMaxQueueSize) {
      _offlineBreadcrumbs.removeAt(0); // keep newest
    }
    _offlineBreadcrumbs.add(item);
    if (_offlineBreadcrumbs.length >= 5) {
      _saveQueueToPrefs();
    }
  }

  static Future<void> _saveQueueToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOfflineQueueKey, jsonEncode(_offlineBreadcrumbs));
    } catch (e) {
      debugPrint('Error saving offline breadcrumbs: $e');
    }
  }

  static Future<void> _loadQueueFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kOfflineQueueKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(str);
        _offlineBreadcrumbs.clear();
        _offlineBreadcrumbs.addAll(decoded.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('Error loading offline breadcrumbs: $e');
    }
  }

  static Future<void> _flushOfflineQueue() async {
    if (_isFlushingQueue || _offlineBreadcrumbs.isEmpty) return;
    _isFlushingQueue = true;
    try {
      final queueCopy = List<Map<String, dynamic>>.from(_offlineBreadcrumbs);
      for (final crumb in queueCopy) {
        try {
          await SupabaseService.postLocation(
            latitude: (crumb['latitude'] as num).toDouble(),
            longitude: (crumb['longitude'] as num).toDouble(),
            speed: (crumb['speed'] as num?)?.toDouble() ?? 0,
            heading: (crumb['heading'] as num?)?.toDouble() ?? 0,
          );
          _offlineBreadcrumbs.remove(crumb);
        } catch (_) {
          // If network connection breaks midway, retain remaining queue
          break;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      if (_offlineBreadcrumbs.isEmpty) {
        await prefs.remove(_kOfflineQueueKey);
      } else {
        await prefs.setString(_kOfflineQueueKey, jsonEncode(_offlineBreadcrumbs));
      }
    } catch (e) {
      debugPrint('Error flushing offline breadcrumbs: $e');
    } finally {
      _isFlushingQueue = false;
    }
  }

  @visibleForTesting
  static void clearOfflineQueue() {
    _offlineBreadcrumbs.clear();
  }

  @visibleForTesting
  static void addTestBreadcrumb(Map<String, dynamic> crumb) {
    _offlineBreadcrumbs.add(crumb);
  }

  @visibleForTesting
  static Future<void> flushQueueForTesting() => _flushOfflineQueue();

  static Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _last = null;
    _lastSentLatLng = null;
    _isTracking = false;
  }
}
