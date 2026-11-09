import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

class GpsTrackingService {
  static StreamSubscription<Position>? _positionSubscription;
  static bool _isTracking = false;

  static bool get isTracking => _isTracking;

  /// Check and request location permissions
  static Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Start live location tracking and streaming to Supabase
  static Future<bool> startTracking({
    required String tripId,
    Function(Position)? onLocationUpdate,
  }) async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return false;

    await stopTracking();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _isTracking = true;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        onLocationUpdate?.call(position);
        try {
          await SupabaseService.updateLocation(
            tripId: tripId,
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed,
            heading: position.heading,
          );
        } catch (e) {
          // Log tracking network blip gracefully
        }
      },
      onError: (err) {
        _isTracking = false;
      },
    );

    return true;
  }

  /// Stop live location tracking
  static Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }
}
