import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/core/services/notification_service.dart';
import 'package:mealgo_driver_app/features/delivery/domain/delivery.dart';

void main() {
  setUp(() {
    NotificationService.instance.cancelAll();
  });

  test('showOfferNotification creates formatted push notification with offer payload', () async {
    const order = DeliveryOrder(
      id: 'deliv-123',
      restaurant: 'Phở Thìn 13 Lò Đúc',
      pickupAddress: '13 Lò Đúc, Hai Bà Trưng',
      customer: 'Nguyễn Văn A',
      dropoffAddress: 'Số 1 Đại Cồ Việt, Bách Khoa',
      item: 'Phở bò tái lăn x2',
      distance: 3.2,
      fee: 35000,
      total: 150000,
    );

    await NotificationService.instance.showOfferNotification(order);

    final recorded = NotificationService.instance.recordedNotifications;
    expect(recorded.length, equals(1));
    expect(recorded.first['title'], contains('Phở Thìn 13 Lò Đúc'));
    expect(recorded.first['body'], contains('Số 1 Đại Cồ Việt'));
    expect(recorded.first['body'], contains('35.000 đ'));
    expect(recorded.first['payload'], equals('offer:deliv-123'));
  });

  test('showCancellationNotification records cancellation reason and payload', () async {
    await NotificationService.instance.showCancellationNotification(
      'Khách hàng đã hủy đơn này',
      orderId: 'deliv-456',
    );

    final recorded = NotificationService.instance.recordedNotifications;
    expect(recorded.length, equals(1));
    expect(recorded.first['title'], contains('Đơn hàng đã bị hủy'));
    expect(recorded.first['body'], equals('Khách hàng đã hủy đơn này'));
    expect(recorded.first['payload'], equals('cancellation:deliv-456'));
  });

  test('showDeliveryCompletedNotification records completion message and payload', () async {
    await NotificationService.instance.showDeliveryCompletedNotification(
      'Giao hàng thành công! Bạn nhận được 40.000 đ.',
      deliveryId: 'deliv-789',
    );

    final recorded = NotificationService.instance.recordedNotifications;
    expect(recorded.length, equals(1));
    expect(recorded.first['title'], contains('Giao hàng thành công'));
    expect(recorded.first['body'], contains('40.000 đ'));
    expect(recorded.first['payload'], equals('delivery_completed:deliv-789'));
  });

  test('showBackendNotification records server notification', () async {
    final serverNotice = {
      'id': 'notice-999',
      'title': 'Cập nhật số dư ví',
      'message': 'Ví của bạn đã được cộng 100.000 đ từ admin.',
      'read': false,
    };

    await NotificationService.instance.showBackendNotification(serverNotice);

    final recorded = NotificationService.instance.recordedNotifications;
    expect(recorded.length, equals(1));
    expect(recorded.first['title'], equals('Cập nhật số dư ví'));
    expect(recorded.first['body'], contains('100.000 đ'));
    expect(recorded.first['payload'], equals('backend_notification:notice-999'));
  });

  test('cancel removes specific notification by id', () async {
    await NotificationService.instance.showNotification(
      id: 101,
      title: 'Thông báo 1',
      body: 'Nội dung 1',
    );
    await NotificationService.instance.showNotification(
      id: 102,
      title: 'Thông báo 2',
      body: 'Nội dung 2',
    );

    expect(NotificationService.instance.recordedNotifications.length, equals(2));

    await NotificationService.instance.cancel(101);

    expect(NotificationService.instance.recordedNotifications.length, equals(1));
    expect(NotificationService.instance.recordedNotifications.first['id'], equals(102));
  });
}
