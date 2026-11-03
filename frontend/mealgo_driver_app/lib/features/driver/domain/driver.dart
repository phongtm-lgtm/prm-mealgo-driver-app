class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.rating,
  });
  final String id;
  final String name;
  final String phone;
  final String vehicle;
  final double rating;
}

class DriverSettings {
  const DriverSettings({
    this.autoAccept = false,
    this.maxDistance = 5,
    this.maxItems = 5,
    this.maxAdvance = 200000,
    this.notifications = true,
  });
  final bool autoAccept;
  final double maxDistance;
  final int maxItems;
  final int maxAdvance;
  final bool notifications;

  DriverSettings copyWith({
    bool? autoAccept,
    double? maxDistance,
    int? maxItems,
    int? maxAdvance,
    bool? notifications,
  }) => DriverSettings(
    autoAccept: autoAccept ?? this.autoAccept,
    maxDistance: maxDistance ?? this.maxDistance,
    maxItems: maxItems ?? this.maxItems,
    maxAdvance: maxAdvance ?? this.maxAdvance,
    notifications: notifications ?? this.notifications,
  );
}

abstract interface class DriverRepository {
  Future<DriverProfile> getProfile();
  Future<DriverSettings> getSettings();
  Future<DriverSettings> saveSettings(DriverSettings settings);
  Future<bool> setOnline(bool online);
}
