import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealgo_driver_app/api_client.dart';
import 'package:mealgo_driver_app/app/app_dependencies.dart';
import 'package:mealgo_driver_app/features/delivery/domain/delivery.dart';
import 'package:mealgo_driver_app/features/delivery/presentation/report_page.dart';
import 'package:mealgo_driver_app/features/home/presentation/driver_controller.dart';

void main() {
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
