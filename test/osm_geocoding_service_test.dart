import 'package:flutter_test/flutter_test.dart';
import 'package:campus_go/services/osm_geocoding_service.dart';

void main() {
  group('OsmLocation Model & Geocoding Tests', () {
    test('creates OsmLocation from campus stop row correctly', () {
      final row = {
        'id': 'stop-123',
        'name': 'Main Gate Bus Terminal',
        'latitude': 18.5678,
        'longitude': 84.1234,
        'route_id': 'route-abc',
      };

      final loc = OsmLocation.fromCampusStop(row);

      expect(loc.id, 'stop-123');
      expect(loc.name, 'Main Gate Bus Terminal');
      expect(loc.displayName, contains('Registered Campus Stop'));
      expect(loc.latitude, 18.5678);
      expect(loc.longitude, 84.1234);
      expect(loc.source, 'campus_stop');
      expect(loc.isCampusStop, isTrue);
      expect(loc.routeId, 'route-abc');
    });

    test('creates OsmLocation from Nominatim JSON correctly', () {
      final json = {
        'place_id': 987654,
        'display_name': 'Tekkali Junction, Srikakulam, Andhra Pradesh, India',
        'lat': '18.6123',
        'lon': '84.2345',
      };

      final loc = OsmLocation.fromNominatimJson(json);

      expect(loc.id, '987654');
      expect(loc.name, 'Tekkali Junction');
      expect(loc.displayName, 'Tekkali Junction, Srikakulam, Andhra Pradesh, India');
      expect(loc.latitude, 18.6123);
      expect(loc.longitude, 84.2345);
      expect(loc.source, 'osm_nominatim');
      expect(loc.isCampusStop, isFalse);
    });

    test('OsmLocation serializes to JSON accurately', () {
      const loc = OsmLocation(
        id: 'loc-1',
        name: 'AITAM Campus',
        displayName: 'AITAM Campus, Tekkali',
        latitude: 18.59,
        longitude: 84.21,
        source: 'campus_stop',
      );

      final json = loc.toJson();
      expect(json['id'], 'loc-1');
      expect(json['name'], 'AITAM Campus');
      expect(json['latitude'], 18.59);
      expect(json['longitude'], 84.21);
      expect(json['source'], 'campus_stop');
    });

    test('searchLocations returns empty on empty query', () async {
      final results = await OsmGeocodingService.searchLocations('   ');
      expect(results, isEmpty);
    });
  });
}
