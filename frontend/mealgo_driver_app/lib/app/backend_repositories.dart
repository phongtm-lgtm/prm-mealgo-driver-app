import '../driver_store.dart';
import '../core/delivery_distance.dart';
import '../features/account/domain/account_repository.dart';
import '../features/delivery/domain/delivery.dart';
import '../features/driver/domain/driver.dart';

/// Maps the server contract to the original UI models. No demo orders are used.
class BackendRepositories
    implements DriverRepository, DeliveryRepository, AccountRepository {
  BackendRepositories(this.store);
  final DriverStore store;
  DriverSettings settings = const DriverSettings();
  final Map<String, Map<String, dynamic>> _orders = {};

  DeliveryOrder mapOrder(Map<String, dynamic> d, {bool offer = false}) {
    final id = (offer ? d['assignmentId'] : d['deliveryId']) as String;
    _orders[id] = d;
    final stages = {
      'ASSIGNED': DeliveryStage.accepted,
      'AT_PICKUP': DeliveryStage.atPickup,
      'PICKED_UP': DeliveryStage.pickedUp,
      'AT_DROPOFF': DeliveryStage.atCustomer,
      'DELIVERED': DeliveryStage.completed,
      'FAILED': DeliveryStage.reported,
    };
    return DeliveryOrder(
      id: id,
      restaurant: d['restaurant']?['name'] ?? 'Điểm lấy hàng',
      pickupAddress: d['pickup']?['address'] ?? '',
      customer: d['recipient']?['name'] ?? 'Điểm giao hàng',
      dropoffAddress: d['dropoff']?['address'] ?? '',
      item: (d['items'] as List? ?? [])
          .map((i) => '${i['quantity']} × ${i['name']}')
          .join(', '),
      distance: deliveryDistanceKm(d['pickup'], d['dropoff']) ?? 0,
      hasDistance: deliveryDistanceKm(d['pickup'], d['dropoff']) != null,
      fee: 0,
      total: (d['payment']?['amountToCollect'] as num? ?? 0).round(),
      stage: stages[d['status']] ?? DeliveryStage.accepted,
    );
  }

  void check() {
    if (store.error != null) throw StateError(store.error!);
  }

  @override
  Future<DriverProfile> getProfile() async {
    await store.refresh();
    check();
    final p = store.profile;
    if (p == null) throw StateError('Tài khoản chưa có hồ sơ tài xế.');
    return DriverProfile(
      id: p['id']?.toString() ?? '',
      name: p['fullName'],
      phone: p['phoneNumber'],
      vehicle: 'Chưa có dữ liệu',
      rating: 0,
    );
  }

  @override
  Future<DriverSettings> getSettings() async => settings;
  @override
  Future<DriverSettings> saveSettings(DriverSettings value) async =>
      settings = value;
  @override
  Future<bool> setOnline(bool online) async {
    await store.setOnline(online);
    check();
    return store.profile?['onlineStatus'] == 'ONLINE';
  }

  @override
  Future<List<DeliveryOrder>> getAvailable() async {
    await store.refresh();
    check();
    return store.offers
        .map((d) => mapOrder(Map<String, dynamic>.from(d), offer: true))
        .toList();
  }

  Future<DeliveryOrder?> current() async {
    final d = await store.api.request('GET', '/drivers/me/deliveries/current');
    store.delivery = d == null ? null : Map<String, dynamic>.from(d);
    return d == null ? null : mapOrder(Map<String, dynamic>.from(d));
  }

  Future<List<DeliveryOrder>> history() async {
    final d = await store.api.request(
      'GET',
      '/drivers/me/deliveries/history?page=0&size=100',
    );
    return (d['items'] as List)
        .map((v) => mapOrder(Map<String, dynamic>.from(v)))
        .toList();
  }

  Future<void> rejectOffer(String id) async {
    await store.respond(id, false);
    check();
  }

  @override
  Future<DeliveryOrder> accept(String id) async {
    await store.respond(id, true);
    check();
    return mapOrder(store.delivery!);
  }

  @override
  Future<DeliveryOrder> advance(String id) async {
    if (!await store.sendLocation())
      throw StateError(store.gpsError ?? 'Chưa có GPS hợp lệ.');
    final d = _orders[id]!;
    final action = {
      'ASSIGNED': 'arrive-at-pickup',
      'AT_PICKUP': 'confirm-pickup',
      'PICKED_UP': 'arrive-at-dropoff',
      'AT_DROPOFF': 'confirm-delivery',
    }[d['status']];
    if (action == null)
      throw StateError('Trạng thái chuyến đã thay đổi. Hãy làm mới.');
    final result = Map<String, dynamic>.from(
      await store.api.request('POST', '/drivers/me/deliveries/$id/$action'),
    );
    store.delivery = result['status'] == 'DELIVERED' ? null : result;
    return mapOrder(result);
  }

  @override
  Future<DeliveryOrder> reject(String id, String reason) async =>
      throw StateError(
        'Backend chưa hỗ trợ hủy chuyến sau khi nhận. Liên hệ hỗ trợ; chuyến vẫn được giữ nguyên.',
      );
  @override
  Future<DeliveryOrder> report(DeliveryReport report) async {
    if (report.bytes == null)
      throw StateError('Vui lòng chọn ảnh bằng chứng thật.');
    final d = _orders[report.orderId]!;
    store.delivery = d;
    final ok = await store.reportFailure(
      report.requestId ?? DriverStore.uuid(),
      {
            'Không liên lạc được với khách': 'CUSTOMER_UNREACHABLE',
            'Khách từ chối nhận hàng': 'CUSTOMER_REFUSED',
          }[report.reason] ??
          'OTHER',
      report.note,
      report.bytes!,
      report.evidence,
    );
    if (!ok) {
      check();
      throw StateError('Không gửi được báo cáo.');
    }
    return mapOrder({...d, 'status': 'FAILED'});
  }

  @override
  Future<AccountSummary> getSummary() async => const AccountSummary(
    balance: 0,
    dailyEarnings: 0,
    weeklyEarnings: 0,
    monthlyEarnings: 0,
    entries: [],
  );
}
