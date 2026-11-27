import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Freshness status of live vehicle telemetry
enum TelemetryFreshness {
  live,
  delayed,
  lost,
}

/// Robust mathematical and physical interpolation engine for live vehicle tracking.
/// Provides Uber/Google Maps-style continuous movement, bearing rotation, and GPS filtering.
class TrackingInterpolator {
  static const Distance _distanceCalculator = Distance();

  /// Linearly interpolates between two [LatLng] coordinates using factor [t] (0.0 to 1.0).
  static LatLng interpolatePosition(LatLng from, LatLng to, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    final lat = from.latitude + clampedT * (to.latitude - from.latitude);
    final lng = from.longitude + clampedT * (to.longitude - from.longitude);
    return LatLng(lat, lng);
  }

  /// Interpolates between two angles in degrees using the shortest angular path.
  /// Seamlessly wraps across the 0° / 360° North boundary.
  static double interpolateHeading(double from, double to, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    // Normalize angles to [0, 360)
    final a = (from % 360.0 + 360.0) % 360.0;
    final b = (to % 360.0 + 360.0) % 360.0;

    // Shortest angular distance between a and b (-180 to +180)
    final diff = ((b - a + 540.0) % 360.0) - 180.0;
    final interpolated = a + clampedT * diff;

    return (interpolated % 360.0 + 360.0) % 360.0;
  }

  /// Calculates the initial bearing (forward azimuth) from [from] to [to] in degrees [0, 360).
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitudeInRad;
    final lon1 = from.longitudeInRad;
    final lat2 = to.latitudeInRad;
    final lon2 = to.longitudeInRad;

    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    final degrees = (radians * 180.0 / math.pi + 360.0) % 360.0;
    return degrees;
  }

  /// Validates an incoming GPS reading based on coordinates and accuracy limits.
  static bool isValidGpsUpdate({
    required double latitude,
    required double longitude,
    required double? accuracy,
    required DateTime timestamp,
    double maxAllowedAccuracy = 45.0,
  }) {
    // 1. Boundary check
    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
      return false;
    }
    // 2. Reject 0,0 null island
    if (latitude.abs() < 0.0001 && longitude.abs() < 0.0001) {
      return false;
    }
    // 3. Accuracy check: ignore readings with large error circles
    if (accuracy != null && accuracy > maxAllowedAccuracy) {
      return false;
    }
    return true;
  }

  /// Detects impossible velocity / teleports caused by multipath GPS reflections.
  /// College buses do not travel faster than 140 km/h (~38.8 m/s).
  static bool isImpossibleJump({
    required LatLng previousPos,
    required DateTime previousTime,
    required LatLng newPos,
    required DateTime newTime,
    double maxSpeedMps = 40.0, // ~144 km/h
  }) {
    final timeDeltaSec = newTime.difference(previousTime).inMilliseconds / 1000.0;
    if (timeDeltaSec <= 0.1) {
      // Extremely close in time; verify displacement
      final distMeters = _distanceCalculator.as(LengthUnit.Meter, previousPos, newPos);
      return distMeters > 50.0;
    }

    final distMeters = _distanceCalculator.as(LengthUnit.Meter, previousPos, newPos);
    final calculatedSpeed = distMeters / timeDeltaSec;

    return calculatedSpeed > maxSpeedMps;
  }

  /// Dampens stationary GPS drift when vehicle is halted at a bus stop or traffic signal.
  static bool isStationary({
    required double displacementMeters,
    required double? speedMps,
    double thresholdSpeed = 0.8, // ~2.8 km/h
    double thresholdDistance = 2.5, // 2.5 meters
  }) {
    if (speedMps != null && speedMps < thresholdSpeed && displacementMeters < thresholdDistance) {
      return true;
    }
    return displacementMeters < 1.5;
  }

  /// Evaluates freshness of live telemetry based on elapsed time since [lastUpdated].
  static TelemetryFreshness getTelemetryState(DateTime? lastUpdated, {DateTime? now}) {
    if (lastUpdated == null) return TelemetryFreshness.lost;
    final current = now ?? DateTime.now();
    final elapsedSec = current.difference(lastUpdated).inSeconds.abs();

    if (elapsedSec < 15) {
      return TelemetryFreshness.live;
    } else if (elapsedSec < 45) {
      return TelemetryFreshness.delayed;
    } else {
      return TelemetryFreshness.lost;
    }
  }

  /// Computes distance in meters between two coordinates.
  static double distanceMeters(LatLng a, LatLng b) {
    return _distanceCalculator.as(LengthUnit.Meter, a, b);
  }
}

/// Controller that drives smooth 60fps vehicle marker movement and rotation.
class LiveVehicleAnimator extends ChangeNotifier {
  final TickerProvider vsync;

  AnimationController? _controller;
  LatLng? _startPosition;
  LatLng? _targetPosition;
  LatLng? _currentPosition;

  double _startHeading = 0.0;
  double _targetHeading = 0.0;
  double _currentHeading = 0.0;

  DateTime? _lastTimestamp;
  Duration _animationDuration = const Duration(milliseconds: 2000);

  bool _isStationary = false;

  LiveVehicleAnimator({required this.vsync}) {
    _controller = AnimationController(
      vsync: vsync,
      duration: _animationDuration,
    )..addListener(_onTick);
  }

  LatLng? get currentPosition => _currentPosition;
  double get currentHeading => _currentHeading;
  bool get isStationary => _isStationary;
  AnimationController? get controller => _controller;

  /// Resets the animator state when switching to another vehicle.
  void reset() {
    _controller?.stop();
    _startPosition = null;
    _targetPosition = null;
    _currentPosition = null;
    _startHeading = 0.0;
    _targetHeading = 0.0;
    _currentHeading = 0.0;
    _lastTimestamp = null;
    _isStationary = false;
    notifyListeners();
  }

  void _onTick() {
    if (_startPosition == null || _targetPosition == null) return;
    final t = Curves.easeInOutSine.transform(_controller!.value);

    _currentPosition = TrackingInterpolator.interpolatePosition(
      _startPosition!,
      _targetPosition!,
      t,
    );

    _currentHeading = TrackingInterpolator.interpolateHeading(
      _startHeading,
      _targetHeading,
      t,
    );

    notifyListeners();
  }

  /// Feeds a new GPS update into the animator.
  void updateTarget({
    required LatLng newPosition,
    double? reportedHeading,
    double? speedMps,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    if (_currentPosition == null) {
      // First position received: immediately initialize without animation
      _startPosition = newPosition;
      _targetPosition = newPosition;
      _currentPosition = newPosition;
      _startHeading = reportedHeading ?? 0.0;
      _targetHeading = reportedHeading ?? 0.0;
      _currentHeading = reportedHeading ?? 0.0;
      _lastTimestamp = now;
      notifyListeners();
      return;
    }

    // Measure distance from current visual position to new target
    final dist = TrackingInterpolator.distanceMeters(_currentPosition!, newPosition);

    // Filter stationary jitter
    if (TrackingInterpolator.isStationary(displacementMeters: dist, speedMps: speedMps)) {
      _isStationary = true;
      // Do not jerk or rotate when stationary
      return;
    }
    _isStationary = false;

    // Derive or use heading
    double resolvedHeading = reportedHeading ?? _currentHeading;
    if (dist > 3.0) {
      final calculated = TrackingInterpolator.calculateBearing(_currentPosition!, newPosition);
      if (reportedHeading == null || reportedHeading <= 0.0) {
        resolvedHeading = calculated;
      }
    }

    // Adaptive animation duration based on update interval
    if (_lastTimestamp != null) {
      final deltaMs = now.difference(_lastTimestamp!).inMilliseconds;
      if (deltaMs > 500 && deltaMs < 6000) {
        _animationDuration = Duration(milliseconds: deltaMs);
      } else {
        _animationDuration = const Duration(milliseconds: 2000);
      }
    } else {
      _animationDuration = const Duration(milliseconds: 2000);
    }
    _lastTimestamp = now;

    // Seamlessly pivot animation from current visual position
    _startPosition = _currentPosition;
    _targetPosition = newPosition;
    _startHeading = _currentHeading;
    _targetHeading = resolvedHeading;

    _controller?.duration = _animationDuration;
    _controller?.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
