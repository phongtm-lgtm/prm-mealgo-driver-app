import '../domain/driver.dart';

class MockDriverRepository implements DriverRepository {
  DriverSettings _settings = const DriverSettings();

  @override
  Future<DriverProfile> getProfile() async => const DriverProfile(
    id: 'MG-20489',
    name: 'Nguyễn Văn An',
    phone: '0987 654 321',
    vehicle: 'Honda Wave • 59-X1 123.45',
    rating: 4.97,
  );

  @override
  Future<DriverSettings> getSettings() async => _settings;

  @override
  Future<DriverSettings> saveSettings(DriverSettings settings) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _settings = settings;
  }

  @override
  Future<bool> setOnline(bool online) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return online;
  }
}
