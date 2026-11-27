import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Represents a road-curved routing calculation result from OSRM or straight-line fallback.
class OsrmRouteResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;
  final bool isRoadGeometry;

  const OsrmRouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isRoadGeometry = true,
  });

  String get formattedDistance => OsrmRoutingService.formatDistance(distanceMeters);
  String get formattedEta => OsrmRoutingService.formatEta(durationSeconds);
}

/// Zero-paid-API Road Routing & Live ETA Engine using Open Source Routing Machine (OSRM).
class OsrmRoutingService {
  static const String _kUserAgent = 'TrackItRide-CBTS/1.0.0 (com.cbts.transport)';
  static const Duration _kNetworkTimeout = Duration(seconds: 4);
  static const double _kAverageBusSpeedMps = 6.94; // ~25 km/h in urban college route

  // In-memory cache for fast lookups and network saving
  static final Map<String, _CachedRoute> _cache = {};
  static const int _kMaxCacheSize = 60;
  static const Duration _kCacheTtl = Duration(minutes: 10);

  /// Fetch a road-following route connecting [start] and [destination].
  /// Returns curved road coordinates, exact distance, and estimated duration.
  /// Falls back gracefully to straight line on network loss or timeout.
  static Future<OsrmRouteResult> fetchRoadRoute(
    LatLng start,
    LatLng destination, {
    http.Client? clientOverride,
  }) async {
    // 1. Trivial check: start and destination are virtually identical
    final directDistance = calculateHaversineDistance(start, destination);
    if (directDistance < 5.0) {
      return OsrmRouteResult(
        polylinePoints: [start, destination],
        distanceMeters: directDistance,
        durationSeconds: 0,
        isRoadGeometry: true,
      );
    }

    // 2. Cache key check (rounded to ~11m precision to reuse nearby points)
    final cacheKey = _buildCacheKey(start, destination);
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _kCacheTtl) {
      return cached.result;
    }

    // 3. Request OSRM Public Routing API
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    final client = clientOverride ?? http.Client();
    try {
      final response = await client.get(
        url,
        headers: {
          'User-Agent': _kUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(_kNetworkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> &&
            data['code'] == 'Ok' &&
            data['routes'] is List &&
            (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0];
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final coordsList = geometry?['coordinates'] as List?;
          final distance = (firstRoute['distance'] as num?)?.toDouble() ?? directDistance;
          final duration = (firstRoute['duration'] as num?)?.toDouble() ?? (distance / _kAverageBusSpeedMps);

          if (coordsList != null && coordsList.isNotEmpty) {
            final points = <LatLng>[];
            for (final item in coordsList) {
              if (item is List && item.length >= 2) {
                final lng = (item[0] as num).toDouble();
                final lat = (item[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }

            if (points.isNotEmpty) {
              final result = OsrmRouteResult(
                polylinePoints: points,
                distanceMeters: distance,
                durationSeconds: duration,
                isRoadGeometry: true,
              );
              _saveToCache(cacheKey, result);
              return result;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM routing fetch exception: $e. Falling back to direct path.');
    } finally {
      if (clientOverride == null) {
        client.close();
      }
    }

    // 4. Graceful Fallback: Straight-line path
    final fallbackDuration = directDistance / _kAverageBusSpeedMps;
    final fallbackResult = OsrmRouteResult(
      polylinePoints: [start, destination],
      distanceMeters: directDistance,
      durationSeconds: fallbackDuration,
      isRoadGeometry: false,
    );
    return fallbackResult;
  }

  /// Calculates the Haversine distance in meters between two coordinates.
  static double calculateHaversineDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _degreesToRadians(p2.latitude - p1.latitude);
    final dLng = _degreesToRadians(p2.longitude - p1.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(p1.latitude)) *
            cos(_degreesToRadians(p2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Formats distance in meters into readable string ("650 m" or "3.2 km").
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Formats duration in seconds into readable ETA ("~4 mins", "< 1 min", "~1 hr 15 mins").
  static String formatEta(double seconds) {
    if (seconds <= 0) return 'Arrived';
    if (seconds < 60) return '< 1 min';
    final totalMins = (seconds / 60).round();
    if (totalMins < 60) {
      return '~$totalMins mins';
    }
    final hours = totalMins ~/ 60;
    final remainingMins = totalMins % 60;
    if (remainingMins == 0) {
      return '~$hours hr${hours > 1 ? 's' : ''}';
    }
    return '~$hours hr $remainingMins min';
  }

  static double _degreesToRadians(double degrees) => degrees * (pi / 180.0);

  static String _buildCacheKey(LatLng start, LatLng destination) {
    return '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}->'
        '${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';
  }

  static void _saveToCache(String key, OsrmRouteResult result) {
    if (_cache.length >= _kMaxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CachedRoute(result: result, timestamp: DateTime.now());
  }

  /// Clear in-memory routing cache (useful for testing)
  @visibleForTesting
  static void clearCache() {
    _cache.clear();
  }
}

class _CachedRoute {
  final OsrmRouteResult result;
  final DateTime timestamp;

  _CachedRoute({required this.result, required this.timestamp});
}
