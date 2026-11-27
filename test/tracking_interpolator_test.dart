import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:campus_go/services/tracking_interpolator.dart';

void main() {
  group('TrackingInterpolator Unit Tests - Uber-Grade Real-Time Tracking', () {
    test('Linear coordinate interpolation between two LatLng points', () {
      const p1 = LatLng(18.5600, 84.1900);
      const p2 = LatLng(18.5700, 84.2000);

      final mid = TrackingInterpolator.interpolatePosition(p1, p2, 0.5);
      expect(mid.latitude, closeTo(18.5650, 0.00001));
      expect(mid.longitude, closeTo(84.1950, 0.00001));

      final start = TrackingInterpolator.interpolatePosition(p1, p2, 0.0);
      expect(start.latitude, closeTo(18.5600, 0.00001));
      expect(start.longitude, closeTo(84.1900, 0.00001));

      final end = TrackingInterpolator.interpolatePosition(p1, p2, 1.0);
      expect(end.latitude, closeTo(18.5700, 0.00001));
      expect(end.longitude, closeTo(84.2000, 0.00001));
    });

    test('Shortest-path angular heading interpolation across 0/360 degree boundary', () {
      // From 350 degrees to 10 degrees (turning right across North 0)
      // Normal arithmetic: 350 + 0.5 * (10 - 350) = 180 (completely wrong - flips South!)
      // Shortest path: difference is +20 degrees, midpoint is 0 / 360 degrees
      final headingAcrossNorth = TrackingInterpolator.interpolateHeading(350.0, 10.0, 0.5);
      expect((headingAcrossNorth - 0.0).abs() < 0.1 || (headingAcrossNorth - 360.0).abs() < 0.1, isTrue);

      // From 10 degrees to 350 degrees (turning left across North 0)
      final headingLeftAcrossNorth = TrackingInterpolator.interpolateHeading(10.0, 350.0, 0.5);
      expect((headingLeftAcrossNorth - 0.0).abs() < 0.1 || (headingLeftAcrossNorth - 360.0).abs() < 0.1, isTrue);

      // From 90 degrees to 180 degrees
      final headingNormal = TrackingInterpolator.interpolateHeading(90.0, 180.0, 0.5);
      expect(headingNormal, closeTo(135.0, 0.1));
    });

    test('Bearing calculation accurately derives direction from successive coordinates', () {
      // Due North
      const pSouth = LatLng(18.5600, 84.1900);
      const pNorth = LatLng(18.5700, 84.1900);
      final bearingNorth = TrackingInterpolator.calculateBearing(pSouth, pNorth);
      expect(bearingNorth, closeTo(0.0, 1.0));

      // Due East
      const pWest = LatLng(18.5600, 84.1900);
      const pEast = LatLng(18.5600, 84.2000);
      final bearingEast = TrackingInterpolator.calculateBearing(pWest, pEast);
      expect(bearingEast, closeTo(90.0, 1.0));
    });

    test('GPS Accuracy & Multipath Jump Rejection', () {
      final now = DateTime.now();

      // 1. Inaccurate GPS reading (> 45m error) must be rejected
      final inaccurate = TrackingInterpolator.isValidGpsUpdate(
        latitude: 18.5665,
        longitude: 84.1952,
        accuracy: 65.0, // poor accuracy
        timestamp: now,
      );
      expect(inaccurate, isFalse);

      // 2. Accurate GPS reading (< 20m error) accepted
      final accurate = TrackingInterpolator.isValidGpsUpdate(
        latitude: 18.5665,
        longitude: 84.1952,
        accuracy: 8.5,
        timestamp: now,
      );
      expect(accurate, isTrue);

      // 3. Impossible location jump (e.g. 500m in 2 seconds = 900 km/h) rejected
      const previous = LatLng(18.5665, 84.1952);
      const jumped = LatLng(18.5765, 84.2052); // ~1.5 km away!
      final isJump = TrackingInterpolator.isImpossibleJump(
        previousPos: previous,
        previousTime: now.subtract(const Duration(seconds: 2)),
        newPos: jumped,
        newTime: now,
      );
      expect(isJump, isTrue);

      // 4. Realistic bus movement (30m in 3 seconds = 36 km/h) accepted
      const normalMove = LatLng(18.5667, 84.1954); // ~30m away
      final isNormalJump = TrackingInterpolator.isImpossibleJump(
        previousPos: previous,
        previousTime: now.subtract(const Duration(seconds: 3)),
        newPos: normalMove,
        newTime: now,
      );
      expect(isNormalJump, isFalse);
    });

    test('Stationary Vehicle Jitter Dampening', () {
      // Minimal displacement (< 2.5m) and low speed (< 0.8 m/s) considered stationary
      final stationary = TrackingInterpolator.isStationary(
        displacementMeters: 1.2,
        speedMps: 0.2,
      );
      expect(stationary, isTrue);

      // Definite movement (15m, 8 m/s) NOT stationary
      final moving = TrackingInterpolator.isStationary(
        displacementMeters: 15.0,
        speedMps: 8.0,
      );
      expect(moving, isFalse);
    });

    test('Staleness / Signal Delay & Loss State Determination', () {
      final now = DateTime.now();

      // < 15 seconds -> LIVE
      expect(
        TrackingInterpolator.getTelemetryState(now.subtract(const Duration(seconds: 5)), now: now),
        TelemetryFreshness.live,
      );

      // 15s to 45s -> DELAYED
      expect(
        TrackingInterpolator.getTelemetryState(now.subtract(const Duration(seconds: 25)), now: now),
        TelemetryFreshness.delayed,
      );

      // > 45s -> LOST
      expect(
        TrackingInterpolator.getTelemetryState(now.subtract(const Duration(seconds: 60)), now: now),
        TelemetryFreshness.lost,
      );

      // Null timestamp -> LOST
      expect(
        TrackingInterpolator.getTelemetryState(null, now: now),
        TelemetryFreshness.lost,
      );
    });
  });
}
