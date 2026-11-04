import '../driver_store.dart';
import '../core/delivery_distance.dart';
import '../features/account/domain/account_repository.dart';
import '../features/delivery/domain/delivery.dart';
import '../features/driver/domain/driver.dart';

/// Maps the server contract to the original UI models. No demo orders are used.
class BackendRepositories
    implements
        DriverRepository,
        DeliveryRepository,
        DeliveryIncidentRepository,
        AccountRepository,
        AccountDataRepository {
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
      'CANCELLED': DeliveryStage.cancelled,
    };
    return DeliveryOrder(
      id: id,
      orderId: d['orderId'] as String?,
      assignmentId: d['assignmentId'] as String?,
      restaurant: d['restaurant']?['name'] ?? 'Điểm lấy hàng',
      pickupAddress: d['pickup']?['address'] ?? '',
      customer: d['recipient']?['name'] ?? 'Điểm giao hàng',
      dropoffAddress: d['dropoff']?['address'] ?? '',
      pickupLatitude: (d['pickup']?['latitude'] as num?)?.toDouble(),
      pickupLongitude: (d['pickup']?['longitude'] as num?)?.toDouble(),
      dropoffLatitude: (d['dropoff']?['latitude'] as num?)?.toDouble(),
      dropoffLongitude: (d['dropoff']?['longitude'] as num?)?.toDouble(),
      item: (d['items'] as List? ?? [])
          .map((i) => '${i['quantity']} × ${i['name']}')
          .join(', '),
      distance: deliveryDistanceKm(d['pickup'], d['dropoff']) ?? 0,
      hasDistance: deliveryDistanceKm(d['pickup'], d['dropoff']) != null,
      fee: ((deliveryDistanceKm(d['pickup'], d['dropoff']) ?? 0) * 10000).round(),
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
  Future<DriverSettings> getSettings() async {
    final order = await store.api.request('GET', '/drivers/me/order-settings');
    final app = await store.api.request('GET', '/drivers/me/app-settings');
    return settings = DriverSettings(
      autoAccept: order['autoAcceptEnabled'] == true,
      maxDistance: (order['maxDeliveryDistanceKm'] as num).toDouble(),
      maxItems: (order['maxItemQuantity'] as num).toInt(),
      maxAdvance: (order['maxRestaurantAdvanceAmount'] as num).round(),
      notifications: app['inAppNotificationsEnabled'] == true,
    );
  }

  @override
  Future<DriverSettings> saveSettings(DriverSettings value) async {
    await store.api.request('PUT', '/drivers/me/order-settings', {
      'autoAcceptEnabled': value.autoAccept,
      'maxDeliveryDistanceKm': value.maxDistance,
      'maxItemQuantity': value.maxItems,
      'maxRestaurantAdvanceAmount': value.maxAdvance,
    });
    await store.api.request('PUT', '/drivers/me/app-settings', {
      'inAppNotificationsEnabled': value.notifications,
    });
    return getSettings();
  }

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

    final ok = await store.sendLocation();

    if (!ok && store.position == null) {

      throw StateError(store.gpsError ?? 'Chưa có GPS hợp lệ.');

    }

    final d = _orders[id]!;

    final action = {

      'ASSIGNED': 'arrive-at-pickup',

      'AT_PICKUP': 'confirm-pickup',

      'PICKED_UP': 'arrive-at-dropoff',

      'AT_DROPOFF': 'confirm-delivery',

    }[d['status']];

    if (action == null)

      throw StateError('Trạng thái chuyến đã thay đổi. Hãy làm mới.');



    final isPickupTarget = d['status'] == 'ASSIGNED' || d['status'] == 'AT_PICKUP';

    final target = isPickupTarget ? d['pickup'] : d['dropoff'];

    final routeMeters = store.routeDistanceMeters;

    if (routeMeters != null) {

      if (routeMeters > 200) {

        throw StateError(

          'Bạn còn cách điểm đến ${routeMeters.round()} m (đường xe máy). Vui lòng di chuyển đến gần hơn (<= 200 m).',

        );

      }

    } else if (store.position != null && target != null) {

      final straightKm = deliveryDistanceKm(target, {

        'latitude': store.position!.latitude,

        'longitude': store.position!.longitude,

      });

      if (straightKm != null && straightKm * 1000 > 200) {

        throw StateError(

          'Bạn còn cách điểm đến ${(straightKm * 1000).round()} m. Vui lòng di chuyển đến gần hơn (<= 200 m).',

        );

      }

    }



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
  Future<Map<String, dynamic>> submitIncident(
    String deliveryId,
    String reason,
    String note,
    String requestId,
    List<int>? bytes,
    String filename,
  ) async {
    final order = _orders[deliveryId];
    if (order == null) throw StateError('Không tìm thấy chuyến. Hãy làm mới.');
    final result = await store.api.deliveryIncident(
      deliveryId,
      {
        'assignmentId': order['assignmentId'] as String,
        'requestId': requestId,
        'reason': reason,
        'note': note,
      },
      bytes,
      filename,
    );
    store.delivery = null;
    return result;
  }

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
  Future<AccountSummary> getSummary() async {
    final w = await wallet();
    return AccountSummary(
      balance: (w['balance'] as num).round(),
      dailyEarnings: 0,
      weeklyEarnings: 0,
      monthlyEarnings: 0,
      entries: [],
    );
  }

  @override
  Future<Map<String, dynamic>> wallet() async => Map<String, dynamic>.from(
    await store.api.request('GET', '/drivers/me/wallet'),
  );

  @override
  Future<Map<String, dynamic>> earnings(String period, String date) async =>
      Map<String, dynamic>.from(
        await store.api.request(
          'GET',
          '/drivers/me/earnings?period=$period&date=$date',
        ),
      );

  @override
  Future<Map<String, dynamic>> accountList(String resource, int page) async =>
      Map<String, dynamic>.from(
        await store.api.request(
          'GET',
          '/drivers/me/$resource?page=$page&size=20',
        ),
      );

  @override
  Future<Map<String, dynamic>> accountDetail(
    String resource,
    String id,
  ) async => Map<String, dynamic>.from(
    await store.api.request('GET', '/drivers/me/$resource/$id'),
  );

  @override
  Future<int> unreadCount() async =>
      ((await store.api.request(
                'GET',
                '/drivers/me/notifications/unread-count',
              ))['count']
              as num)
          .toInt();

  @override
  Future<void> markRead(String? id) async {
    await store.api.request(
      'PATCH',
      id == null
          ? '/drivers/me/notifications/read-all'
          : '/drivers/me/notifications/$id/read',
    );
  }

  @override
  Future<DriverProfileData> updateProfile(String name, String phone) async =>
      Map<String, dynamic>.from(
        await store.api.request('PUT', '/drivers/me/profile', {
          'fullName': name,
          'phoneNumber': phone,
        }),
      );
}
