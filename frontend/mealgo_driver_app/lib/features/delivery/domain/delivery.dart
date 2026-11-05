enum DeliveryStage {
  accepted('Đã nhận đơn hàng', 'Đã đến điểm lấy'),
  atPickup('Đã đến quán', 'Đã lấy hàng'),
  pickedUp('Đang giao đến khách', 'Đã đến điểm giao'),
  atCustomer('Đã đến điểm giao', 'Hoàn thành giao hàng'),
  completed('Giao hàng thành công', ''),
  cancelled('Đã hủy đơn', ''),
  reported('Đã báo giao thất bại', '');

  const DeliveryStage(this.label, this.action);
  final String label;
  final String action;
  bool get isTerminal => index >= completed.index;
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    this.orderId,
    this.assignmentId,
    this.orderStatus,
    this.cancellationCode,
    required this.restaurant,
    required this.pickupAddress,
    required this.customer,
    required this.dropoffAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    required this.item,
    required this.distance,
    this.hasDistance = true,
    required this.fee,
    required this.total,
    this.stage = DeliveryStage.accepted,
  });
  final String id;

  /// Business order and assignment IDs are distinct from this delivery ID.
  final String? orderId;
  final String? assignmentId;
  final String? orderStatus;
  final String? cancellationCode;
  final String restaurant;
  final String pickupAddress;
  final String customer;
  final String dropoffAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String item;
  final double distance;
  final bool hasDistance;
  final int fee;
  final int total;
  final DeliveryStage stage;
  bool get canRelease =>
      orderStatus == 'PREPARING' &&
      (stage == DeliveryStage.accepted || stage == DeliveryStage.atPickup);

  DeliveryOrder withStage(DeliveryStage value) => DeliveryOrder(
    id: id,
    orderId: orderId,
    assignmentId: assignmentId,
    orderStatus: orderStatus,
    cancellationCode: cancellationCode,
    restaurant: restaurant,
    pickupAddress: pickupAddress,
    customer: customer,
    dropoffAddress: dropoffAddress,
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
    dropoffLatitude: dropoffLatitude,
    dropoffLongitude: dropoffLongitude,
    item: item,
    distance: distance,
    hasDistance: hasDistance,
    fee: fee,
    total: total,
    stage: value,
  );
}

class DeliveryReport {
  const DeliveryReport({
    required this.orderId,
    required this.reason,
    required this.note,
    required this.evidence,
    this.bytes,
    this.requestId,
  });
  final String orderId;
  final String reason;
  final String note;
  final String evidence;
  final List<int>? bytes;
  final String? requestId;
}

abstract interface class DeliveryRepository {
  Future<List<DeliveryOrder>> getAvailable();
  Future<List<DeliveryOrder>> refreshOffers(List<DeliveryOrder> skipped);
  Future<DeliveryOrder> accept(String id);
  Future<DeliveryOrder> advance(String id);
  Future<DeliveryOrder> reject(String id, String reason);
  Future<DeliveryOrder> report(DeliveryReport report);
}

abstract interface class DeliveryIncidentRepository {
  Future<Map<String, dynamic>> submitIncident(
    String deliveryId,
    String reason,
    String note,
    String requestId,
    List<int>? bytes,
    String filename,
  );
}
