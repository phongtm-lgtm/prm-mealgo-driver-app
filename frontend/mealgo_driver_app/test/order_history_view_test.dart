import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/features/account/presentation/order_history_view.dart';

void main() {
  testWidgets(
    'History shows real stops and filters loaded rows by Vietnam day',
    (tester) async {
      final now = DateTime.now();
      Map<String, dynamic>? opened;
      var more = 0;
      final rows = [
        {
          'deliveryId': '12345678-abcd',
          'status': 'DELIVERED',
          'deliveredAt': now.toUtc().toIso8601String(),
          'restaurant': {'name': 'Bếp Nhà'},
          'pickup': {'address': '12 Nguyễn Trãi'},
          'dropoff': {'address': '45 Lê Lợi'},
        },
        {
          'deliveryId': 'old-order',
          'status': 'FAILED',
          'failedAt': now
              .subtract(const Duration(days: 10))
              .toUtc()
              .toIso8601String(),
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderHistoryView(
                rows: rows,
                loading: false,
                failed: false,
                hasNext: true,
                onMore: () => more++,
                onOpen: (row) => opened = row,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Bếp Nhà'), findsOneWidget);
      expect(find.text('12 Nguyễn Trãi'), findsOneWidget);
      expect(find.text('45 Lê Lợi'), findsOneWidget);
      expect(find.text('2 đơn'), findsOneWidget);
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('1 đơn'), findsOneWidget);
      expect(find.text('Giao không thành công'), findsNothing);
      await tester.tap(find.text('Xem chi tiết chuyến'));
      expect(opened, rows.first);
      await tester.ensureVisible(find.text('Tải thêm đơn hàng'));
      await tester.tap(find.text('Tải thêm đơn hàng'));
      expect(more, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
