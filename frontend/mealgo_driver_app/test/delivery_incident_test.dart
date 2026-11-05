import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealgo_driver_app/api_client.dart';
import 'package:mealgo_driver_app/app/app_dependencies.dart';
import 'package:mealgo_driver_app/app/backend_repositories.dart';
import 'package:mealgo_driver_app/driver_store.dart';
import 'package:mealgo_driver_app/features/delivery/domain/delivery.dart';
import 'package:mealgo_driver_app/features/delivery/presentation/report_page.dart';
import 'package:mealgo_driver_app/features/home/presentation/driver_controller.dart';
import 'package:mealgo_driver_app/features/home/presentation/home_page.dart';

void main() {
  testWidgets('Bottom bar releases the trip, confirms redistribution and returns online', (tester) async {
    final controller = DriverController(AppDependencies.mock());
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.setOnline(true);
      await controller.accept(controller.available.first);
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: HomePage(controller: controller)));
    await tester.tap(find.text('Báo cáo đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Quán đóng cửa'), findsOneWidget);
    await tester.tap(find.text('Khách không nghe máy'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm ảnh chụp lịch sử cuộc gọi nhỡ (PNG hoặc JPEG, tối đa 5 MB).'), findsOneWidget);
    await tester.ensureVisible(find.text('Gửi ảnh và bỏ chuyến'));
    await tester.tap(find.text('Gửi ảnh và bỏ chuyến'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng đính kèm ảnh chụp lịch sử cuộc gọi nhỡ.'), findsOneWidget);
    expect(controller.activeOrder, isNotNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy chuyến'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xe hỏng'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xác nhận chuyển đơn'));
    await tester.tap(find.text('Xác nhận chuyển đơn'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Đơn hàng sẽ được phân phối cho tài xế khác'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    expect(controller.activeOrder, isNull);
    expect(controller.showingActive, isFalse);
    expect(controller.online, isTrue);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('Missed calls at dropoff open the failure report with call evidence', (tester) async {
    final controller = DriverController(AppDependencies.mock());
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.setOnline(true);
      await controller.accept(controller.available.first);
      await controller.advance();
      await controller.advance();
      await controller.advance();
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: HomePage(controller: controller)));
    expect(find.text('Hủy chuyến'), findsNothing);
    await tester.tap(find.text('Báo cáo đơn hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khách không nghe máy'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportPage), findsOneWidget);
    expect(find.text('Đính kèm ảnh chụp lịch sử cuộc gọi'), findsOneWidget);
  });

  testWidgets('Remote cancellation closes the issue sheet and shows the reason once', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final active = {
      'deliveryId': 'trip-1', 'assignmentId': 'assignment-1',
      'status': 'ASSIGNED', 'orderStatus': 'PREPARING',
    };
    var cancelled = false;
    final store = DriverStore(api: ApiClient(client: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/current')) {
        return http.Response(cancelled ? '' : jsonEncode(active), cancelled ? 204 : 200);
      }
      if (path.endsWith('/history/trip-1')) {
        return http.Response(jsonEncode({...active, 'status': 'CANCELLED',
          'orderStatus': 'CANCELLED', 'cancellationCode': 'RESTAURANT_OUT_OF_STOCK'}), 200);
      }
      if (path.endsWith('/offers')) return http.Response('[]', 200);
      if (path.endsWith('/history')) return http.Response('{"items":[]}', 200);
      throw StateError('Unexpected call $path');
    })))..profile = {'onlineStatus': 'ONLINE'};
    final mock = AppDependencies.mock();
    final controller = DriverController(AppDependencies(
      driver: mock.driver, account: mock.account, delivery: BackendRepositories(store)));
    addTearDown(() { controller.dispose(); store.dispose(); });
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(MaterialApp(home: HomePage(controller: controller)));
    await tester.tap(find.text('Báo cáo đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Quán đóng cửa'), findsOneWidget);
    cancelled = true;
    controller.syncFromServer();
    await tester.pumpAndSettle();
    expect(find.text('Quán đóng cửa'), findsNothing);
    expect(find.text('Nhà hàng đã hủy đơn do hết món'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    controller.syncFromServer();
    await tester.pumpAndSettle();
    expect(find.text('Nhà hàng đã hủy đơn do hết món'), findsNothing);
    expect(controller.activeOrder, isNull);
    expect(controller.online, isTrue);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
  test(
    'incident sends assignment, stable request key and evidence as multipart',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/drivers/me/deliveries/delivery-id/incident',
          );
          expect(request.headers['Authorization'], 'Bearer jwt');
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );
          expect(request.body, contains('assignment-id'));
          expect(request.body, contains('same-retry-key'));
          expect(request.body, contains('RESTAURANT_CLOSED'));
          expect(request.body, contains('proof.png'));
          return http.Response(jsonEncode({'outcome': 'CANCELLED'}), 200);
        }),
      )..token = 'jwt';
      final result = await api.deliveryIncident(
        'delivery-id',
        {
          'assignmentId': 'assignment-id',
          'requestId': 'same-retry-key',
          'reason': 'RESTAURANT_CLOSED',
        },
        [1, 2, 3],
        'proof.png',
      );
      expect(result['outcome'], 'CANCELLED');
      api.close();
    },
  );

  testWidgets('failure report is disabled before arrival at customer', (
    tester,
  ) async {
    final controller = DriverController(AppDependencies.mock());
    const order = DeliveryOrder(
      id: 'delivery',
      restaurant: 'Quán',
      pickupAddress: 'A',
      customer: 'Khách',
      dropoffAddress: 'B',
      item: 'Cơm',
      distance: 1,
      fee: 0,
      total: 10000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReportPage(controller: controller, order: order),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa đủ điều kiện báo cáo'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Gửi báo cáo'),
    );
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
