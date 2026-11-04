import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/features/account/presentation/wallet_view.dart';

void main() {
  testWidgets('Wallet fits a small phone and shows only five recent entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var all = false;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WalletView(
              wallet: const {'balance': 350000, 'earningsConfigured': true},
              earnings: const {'totalEarnings': 125000},
              rows: List.generate(
                6,
                (i) => {
                  'id': '$i',
                  'type': 'DELIVERY_EARNING',
                  'amount': 25000,
                  'createdAt': '2026-11-04T10:0$i:00Z',
                },
              ),
              loading: false,
              failed: false,
              onAll: () => all = true,
              onOpen: (_) => opened = true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('350.000đ'), findsOneWidget);
    expect(find.text('125.000đ'), findsOneWidget);
    expect(find.text('Thu nhập giao hàng'), findsNWidgets(5));
    expect(find.text('Tiền đang xử lý'), findsNothing);
    await tester.ensureVisible(find.text('Xem tất cả'));
    await tester.tap(find.text('Xem tất cả'));
    expect(all, isTrue);
    await tester.ensureVisible(find.text('Thu nhập giao hàng').first);
    await tester.tap(find.text('Thu nhập giao hàng').first);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
