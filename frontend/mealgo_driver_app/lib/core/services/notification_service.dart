import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/delivery/domain/delivery.dart';
import '../formatters.dart';

/// Service quản lý hiển thị thông báo đẩy trên điện thoại (OS Notification Bar, Lockscreen, Banner)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FlutterLocalNotificationsPlugin? _pluginInstance;
  FlutterLocalNotificationsPlugin get _plugin =>
      _pluginInstance ??= FlutterLocalNotificationsPlugin();

  final StreamController<String?> _onNotificationClick =
      StreamController<String?>.broadcast();

  Stream<String?> get onNotificationClick => _onNotificationClick.stream;

  bool _initialized = false;
  bool isTestMode = false;
  final List<Map<String, dynamic>> recordedNotifications = [];

  bool get _isTest {
    if (isTestMode) return true;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static const String _channelId = 'mealgo_driver_alerts_v2';
  static const String _channelName = 'Thông báo Đơn hàng MealGo Driver';
  static const String _channelDescription =
      'Thông báo đơn hàng mới, cập nhật trạng thái quán xong món và sự cố cuốc xe';

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Khởi tạo notification service
  Future<void> init({void Function(String?)? onSelectNotification}) async {
    if (_initialized) return;

    if (onSelectNotification != null) {
      _onNotificationClick.stream.listen(onSelectNotification);
    }

    if (_isTest) {
      _initialized = true;
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _onNotificationClick.add(response.payload);
        },
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_androidChannel);

      // Yêu cầu cấp quyền hiển thị thông báo ngay khi khởi chạy
      await requestPermissions();

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Xin quyền hiển thị thông báo trên Android 13+ (POST_NOTIFICATIONS) và iOS
  Future<bool> requestPermissions() async {
    if (_isTest) return true;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final androidGranted =
          await androidPlugin?.requestNotificationsPermission();

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      return (androidGranted ?? true) && (iosGranted ?? true);
    } catch (e) {
      debugPrint('NotificationService requestPermissions error: $e');
      return false;
    }
  }

  /// Hiển thị thông báo đẩy tổng quát
  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final notificationId =
        id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000).abs();

    if (_isTest) {
      recordedNotifications.add({
        'id': notificationId,
        'title': title,
        'body': body,
        'payload': payload,
      });
      return;
    }

    try {

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        visibility: NotificationVisibility.public,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService showNotification error: $e');
    }
  }

  /// Thông báo đẩy khi có đơn hàng mới (Order Offer)
  Future<void> showOfferNotification(DeliveryOrder order) async {
    final title = '🔔 Có đơn hàng mới! (${order.restaurant})';
    final body =
        'Giao đến: ${order.dropoffAddress}\nThu nhập: ${money(order.fee)} • Nhấn để nhận đơn ngay!';
    await showNotification(
      id: order.id.hashCode.abs() % 100000,
      title: title,
      body: body,
      payload: 'offer:${order.id}',
    );
  }

  /// Thông báo đẩy khi đơn hàng bị hủy không do tài xế
  Future<void> showCancellationNotification(
    String message, {
    String? orderId,
  }) async {
    const title = '⚠️ Đơn hàng đã bị hủy';
    final body = message.isNotEmpty ? message : 'Khách hàng hoặc quán đã hủy đơn này.';
    await showNotification(
      id: (orderId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs() %
          100000,
      title: title,
      body: body,
      payload: 'cancellation:${orderId ?? ''}',
    );
  }

  /// Thông báo đẩy khi nhà hàng đã làm xong món (Order status: READY)
  Future<void> showFoodReadyNotification(DeliveryOrder order) async {
    final title = '🍳 Nhà hàng đã làm xong món!';
    final body =
        '${order.restaurant} đã chuẩn bị xong: ${order.item}. Mời bạn đến quán lấy hàng!';
    await showNotification(
      id: (order.id.hashCode + 101).abs() % 100000,
      title: title,
      body: body,
      payload: 'delivery:${order.id}',
    );
  }

  /// Thông báo đẩy khi giao hàng thành công
  Future<void> showDeliveryCompletedNotification(
    String message, {
    String? deliveryId,
  }) async {
    const title = '🎉 Giao hàng thành công!';
    await showNotification(
      id: (deliveryId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs() %
          100000,
      title: title,
      body: message,
      payload: 'delivery_completed:${deliveryId ?? ''}',
    );
  }

  /// Thông báo đẩy cho thông báo từ Backend (DriverNotification)
  Future<void> showBackendNotification(Map<String, dynamic> notification) async {
    final title = notification['title'] as String? ?? 'Thông báo MealGo';
    final message = notification['message'] as String? ?? '';
    final id = notification['id'] as String?;
    final int notifId =
        (id?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs() % 100000;

    await showNotification(
      id: notifId,
      title: title,
      body: message,
      payload: 'backend_notification:${id ?? ''}',
    );
  }

  /// Xóa thông báo theo ID
  Future<void> cancel(int id) async {
    if (_isTest) {
      recordedNotifications.removeWhere((n) => n['id'] == id);
      return;
    }
    await _plugin.cancel(id: id);
  }

  /// Xóa toàn bộ thông báo đã hiển thị
  Future<void> cancelAll() async {
    if (_isTest) {
      recordedNotifications.clear();
      return;
    }
    await _plugin.cancelAll();
  }
}
