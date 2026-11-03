import '../domain/delivery.dart';

class MockDeliveryRepository implements DeliveryRepository {
  final Map<String, DeliveryOrder> _available = {
    'MG-1024': const DeliveryOrder(
      id: 'MG-1024',
      restaurant: 'Cơm Tấm Sài Gòn',
      pickupAddress: '128 Nguyễn Trãi, P. Bến Thành, Quận 1',
      customer: 'Nguyễn V*** • 0987 *** 321',
      dropoffAddress: '85 Cách Mạng Tháng 8, Quận 1, TP. HCM',
      item: 'Cơm tấm sườn bì chả',
      distance: 1.9,
      fee: 13500,
      total: 59000,
    ),
    'MG-1025': const DeliveryOrder(
      id: 'MG-1025',
      restaurant: 'Tea Pops • Trà sữa & Cà phê',
      pickupAddress: '42 Lê Văn Sỹ, Phường 13, Quận 3',
      customer: 'Trần T*** • 0903 *** 456',
      dropoffAddress: '120 Võ Văn Tần, Quận 3, TP. HCM',
      item: 'Trà sữa trân châu đường đen',
      distance: 2.4,
      fee: 18000,
      total: 45000,
    ),
    'MG-1026': const DeliveryOrder(
      id: 'MG-1026',
      restaurant: 'Bún Bò Huế • Mộc',
      pickupAddress: '210 Điện Biên Phủ, Quận Bình Thạnh',
      customer: 'Lê H*** • 0912 *** 789',
      dropoffAddress: '18 Nguyễn Hữu Cảnh, Quận Bình Thạnh',
      item: 'Bún bò đặc biệt',
      distance: 3.2,
      fee: 24000,
      total: 65000,
    ),
  };
  final Map<String, DeliveryOrder> _accepted = {};
  final List<DeliveryReport> reports = [];

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  @override
  Future<List<DeliveryOrder>> getAvailable() async {
    await _delay();
    return List.unmodifiable(_available.values);
  }

  @override
  Future<DeliveryOrder> accept(String id) async {
    await _delay();
    if (_accepted.values.any((order) => !order.stage.isTerminal)) {
      throw StateError('Bạn đang có đơn cần hoàn thành.');
    }
    final order = _available.remove(id);
    if (order == null) {
      throw StateError('Đơn không còn khả dụng. Vui lòng chọn đơn khác.');
    }
    return _accepted[id] = order;
  }

  DeliveryOrder _findActive(String id) {
    final order = _accepted[id];
    if (order == null || order.stage.isTerminal) {
      throw StateError('Đơn hàng không còn hoạt động.');
    }
    return order;
  }

  @override
  Future<DeliveryOrder> advance(String id) async {
    await _delay();
    final order = _findActive(id);
    return _accepted[id] = order.withStage(
      DeliveryStage.values[order.stage.index + 1],
    );
  }

  @override
  Future<DeliveryOrder> reject(String id, String reason) async {
    await _delay();
    if (reason.trim().isEmpty) throw ArgumentError('Vui lòng chọn lý do.');
    final order = _findActive(id);
    if (order.stage.index > DeliveryStage.atPickup.index) {
      throw StateError('Đơn đã lấy hàng. Vui lòng dùng chức năng báo cáo.');
    }
    return _accepted[id] = order.withStage(DeliveryStage.cancelled);
  }

  @override
  Future<DeliveryOrder> report(DeliveryReport report) async {
    await _delay();
    final order = _findActive(report.orderId);
    if (order.stage != DeliveryStage.atCustomer) {
      throw StateError('Chỉ báo cáo giao thất bại tại điểm giao.');
    }
    if (report.evidence.isEmpty ||
        report.note.trim().isEmpty ||
        report.reason.isEmpty) {
      throw ArgumentError('Vui lòng bổ sung mô tả và bằng chứng.');
    }
    reports.add(report);
    return _accepted[order.id] = order.withStage(DeliveryStage.reported);
  }
}
