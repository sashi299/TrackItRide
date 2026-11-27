import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

/// Represents a geographic location derived from either a registered campus stop
/// or an OpenStreetMap (OSM) Nominatim free geocoded location.
class OsmLocation {
  final String id;
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String source; // 'campus_stop' | 'osm_nominatim'
  final String? routeId;

  const OsmLocation({
    required this.id,
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.routeId,
  });

  bool get isCampusStop => source == 'campus_stop';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
        'route_id': routeId,
      };

  factory OsmLocation.fromCampusStop(Map<String, dynamic> row) {
    return OsmLocation(
      id: row['id']?.toString() ?? UniqueKey().toString(),
      name: row['name']?.toString() ?? 'Campus Stop',
      displayName: '${row['name'] ?? 'Stop'} (Registered Campus Stop)',
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      source: 'campus_stop',
      routeId: row['route_id']?.toString(),
    );
  }

  factory OsmLocation.fromNominatimJson(Map<String, dynamic> json) {
    final displayName = json['display_name']?.toString() ?? 'Selected Location';
    final parts = displayName.split(',');
    final shortName = parts.isNotEmpty ? parts.first.trim() : displayName;

    return OsmLocation(
      id: json['place_id']?.toString() ?? UniqueKey().toString(),
      name: shortName,
      displayName: displayName,
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      source: 'osm_nominatim',
    );
  }

  @override
  String toString() => '$name ($latitude, $longitude)';
}

/// Zero-dependency service for OSM Nominatim geocoding & Supabase stops search.
class OsmGeocodingService {
  static const String _kUserAgent = 'TrackItRide-CBTS/1.0.0 (com.cbts.transport)';
  static const Duration _kNetworkTimeout = Duration(seconds: 4);

  /// Search locations matching [query] across campus stops and OSM Nominatim.
  static Future<List<OsmLocation>> searchLocations(String query, {int limit = 8}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final results = <OsmLocation>[];

    // 1. Campus Stops Search from Supabase
    try {
      final stopsData = await SupabaseService.client
          .from('stops')
          .select('id, name, latitude, longitude, route_id')
          .ilike('name', '%$cleanQuery%')
          .limit(limit);

      for (final row in List<Map<String, dynamic>>.from(stopsData)) {
        if (row['latitude'] != null && row['longitude'] != null) {
          results.add(OsmLocation.fromCampusStop(row));
        }
      }
    } catch (e) {
      debugPrint('Campus stops search error: $e');
    }

    // 2. OSM Nominatim Free Geocoding API
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&limit=5&countrycodes=in',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _kUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(_kNetworkTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final loc = OsmLocation.fromNominatimJson(item);
            // Avoid adding duplicates that are too close to existing campus stops (< 100m)
            final isDuplicate = results.any(
              (r) => (r.latitude - loc.latitude).abs() < 0.001 &&
                  (r.longitude - loc.longitude).abs() < 0.001,
            );
            if (!isDuplicate && loc.latitude != 0.0 && loc.longitude != 0.0) {
              results.add(loc);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('OSM Nominatim geocoding error: $e');
    }

    return results.take(limit).toList();
  }

  /// Reverse geocode coordinates to a human-readable street or area address.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _kUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(_kNetworkTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final address = json['address'];
        if (address is Map<String, dynamic>) {
          final road = address['road'] ?? address['neighbourhood'] ?? address['suburb'];
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'];
          if (road != null && city != null) {
            return '$road, $city';
          }
        }
        final displayName = json['display_name']?.toString();
        if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',');
          if (parts.length >= 3) {
            return '${parts[0].trim()}, ${parts[1].trim()}, ${parts[2].trim()}';
          }
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }

    return 'Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }
}
