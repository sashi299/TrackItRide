import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:campus_go/services/osrm_routing_service.dart';

void main() {
  setUp(() {
    OsrmRoutingService.clearCache();
  });

  group('OsrmRoutingService Unit & Distance Tests', () {
    test('calculateHaversineDistance computes accurate distance', () {
      // 1 degree lat is approx 111 km
      const p1 = LatLng(17.0000, 81.0000);
      const p2 = LatLng(17.0100, 81.0000);
      final distance = OsrmRoutingService.calculateHaversineDistance(p1, p2);
      expect(distance, greaterThan(1100));
      expect(distance, lessThan(1125));
    });

    test('formatDistance formats meters and kilometers properly', () {
      expect(OsrmRoutingService.formatDistance(350), '350 m');
      expect(OsrmRoutingService.formatDistance(999), '999 m');
      expect(OsrmRoutingService.formatDistance(1000), '1.0 km');
      expect(OsrmRoutingService.formatDistance(2450), '2.5 km');
      expect(OsrmRoutingService.formatDistance(12800), '12.8 km');
    });

    test('formatEta formats seconds into human readable time', () {
      expect(OsrmRoutingService.formatEta(0), 'Arrived');
      expect(OsrmRoutingService.formatEta(45), '< 1 min');
      expect(OsrmRoutingService.formatEta(300), '~5 mins');
      expect(OsrmRoutingService.formatEta(3600), '~1 hr');
      expect(OsrmRoutingService.formatEta(4500), '~1 hr 15 min');
    });

    test('fetchRoadRoute returns parsed road coordinates when OSRM succeeds', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'router.project-osrm.org');
        final fakeJson = {
          'code': 'Ok',
          'routes': [
            {
              'distance': 3450.0,
              'duration': 510.0,
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [81.7785, 17.0005],
                  [81.7790, 17.0010],
                  [81.7800, 17.0025],
                ],
              },
            }
          ]
        };
        return http.Response(jsonEncode(fakeJson), 200, headers: {'content-type': 'application/json'});
      });

      const start = LatLng(17.0005, 81.7785);
      const dest = LatLng(17.0025, 81.7800);

      final result = await OsrmRoutingService.fetchRoadRoute(
        start,
        dest,
        clientOverride: mockClient,
      );

      expect(result.isRoadGeometry, isTrue);
      expect(result.polylinePoints.length, 3);
      expect(result.polylinePoints.first.latitude, closeTo(17.0005, 0.0001));
      expect(result.polylinePoints.last.latitude, closeTo(17.0025, 0.0001));
      expect(result.distanceMeters, 3450.0);
      expect(result.formattedDistance, '3.5 km');
      expect(result.formattedEta, '~9 mins');
    });

    test('fetchRoadRoute falls back gracefully to straight line on HTTP failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      const start = LatLng(17.0000, 81.0000);
      const dest = LatLng(17.0100, 81.0000);

      final result = await OsrmRoutingService.fetchRoadRoute(
        start,
        dest,
        clientOverride: mockClient,
      );

      expect(result.isRoadGeometry, isFalse);
      expect(result.polylinePoints.length, 2);
      expect(result.polylinePoints.first, start);
      expect(result.polylinePoints.last, dest);
      expect(result.distanceMeters, greaterThan(1100));
    });
  });
}
