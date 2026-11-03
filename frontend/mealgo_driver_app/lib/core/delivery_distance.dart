import 'dart:math' as math;

/// Great-circle distance, not a road route or the driver's distance to pickup.
double? deliveryDistanceKm(dynamic pickup, dynamic dropoff) {
  if (pickup is! Map || dropoff is! Map) return null;
  final lat1 = pickup['latitude'];
  final lon1 = pickup['longitude'];
  final lat2 = dropoff['latitude'];
  final lon2 = dropoff['longitude'];
  if (lat1 is! num || lon1 is! num || lat2 is! num || lon2 is! num) {
    return null;
  }
  if (![lat1, lon1, lat2, lon2].every((v) => v.isFinite) ||
      lat1.abs() > 90 ||
      lat2.abs() > 90 ||
      lon1.abs() > 180 ||
      lon2.abs() > 180)
    return null;
  const radians = math.pi / 180;
  final a =
      math.pow(math.sin((lat2 - lat1) * radians / 2), 2) +
      math.cos(lat1 * radians) *
          math.cos(lat2 * radians) *
          math.pow(math.sin((lon2 - lon1) * radians / 2), 2);
  return 6371 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}

String formatDeliveryDistance(double distance, {bool available = true}) {
  if (!available) return 'Chưa có khoảng cách';
  if (distance < 1) return '${(distance * 1000).round()} m';
  return '${distance.toStringAsFixed(2)} km';
}
