import 'package:flutter_test/flutter_test.dart';

import '../lib/core/delivery_distance.dart';

void main() {
  test('distance between local pickup and dropoff is about 50 metres', () {
    final distance = deliveryDistanceKm(
      {'latitude': 10.7626, 'longitude': 106.6823},
      {'latitude': 10.7630, 'longitude': 106.6825},
    );
    expect(distance, closeTo(0.0496, 0.001));
    expect(formatDeliveryDistance(distance!), '50 m');
  });
  test('missing or invalid coordinates are not treated as zero distance', () {
    expect(deliveryDistanceKm(null, {}), isNull);
    expect(
      deliveryDistanceKm(
        {'latitude': 91, 'longitude': 0},
        {'latitude': 0, 'longitude': 0},
      ),
      isNull,
    );
    expect(formatDeliveryDistance(0, available: false), 'Chưa có khoảng cách');
  });
  test('identical coordinates are valid zero distance', () {
    expect(
      deliveryDistanceKm(
        {'latitude': 0, 'longitude': 0},
        {'latitude': 0, 'longitude': 0},
      ),
      0,
    );
  });
}
