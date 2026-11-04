import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/features/account/presentation/earnings_view.dart';

void main() {
  testWidgets('Earnings uses actual totals without bonuses on small phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EarningsView(
              data: {
                'totalEarnings': 160000,
                'completedDeliveries': 8,
                'earningsConfigured': true,
                'fromDate': '2026-11-02',
                'toDate': '2026-11-08',
                'chart': List.generate(
                  7,
                  (i) => {
                    'date': '2026-11-0${i + 2}',
                    'earnings': i == 0 ? 160000 : 0,
                  },
                ),
              },
              onTransactions: () => opened = true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('8 đơn'), findsOneWidget);
    expect(find.text('20.000đ'), findsOneWidget);
    expect(find.text('Tiền thưởng'), findsNothing);
    expect(find.text('160.000đ'), findsNWidgets(3));
    await tester.ensureVisible(find.text('Xem lịch sử giao dịch'));
    await tester.tap(find.text('Xem lịch sử giao dịch'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
