import 'package:flutter_test/flutter_test.dart';
import 'package:campus_go/services/gps_tracking_service.dart';

void main() {
  setUp(() {
    GpsTrackingService.clearOfflineQueue();
  });

  group('GpsTrackingService Offline Breadcrumbs FIFO Queue', () {
    test('initial queue is empty', () {
      expect(GpsTrackingService.offlineQueueLength, 0);
    });

    test('addTestBreadcrumb enqueues telemetry points', () {
      GpsTrackingService.addTestBreadcrumb({
        'latitude': 17.0010,
        'longitude': 81.7800,
        'speed': 5.2,
        'heading': 90.0,
        'timestamp': DateTime.now().toIso8601String(),
      });

      expect(GpsTrackingService.offlineQueueLength, 1);
    });

    test('clearOfflineQueue resets queue to zero', () {
      GpsTrackingService.addTestBreadcrumb({
        'latitude': 17.0010,
        'longitude': 81.7800,
        'speed': 5.2,
        'heading': 90.0,
        'timestamp': DateTime.now().toIso8601String(),
      });
      expect(GpsTrackingService.offlineQueueLength, 1);

      GpsTrackingService.clearOfflineQueue();
      expect(GpsTrackingService.offlineQueueLength, 0);
    });
  });
}
