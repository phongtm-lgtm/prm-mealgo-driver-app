import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/features/account/presentation/transaction_history_view.dart';

void main() {
  testWidgets(
    'Shows friendly transactions and hides partial totals on small phones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      final row = <String, dynamic>{
        'id': 'long-transaction-id',
        'type': 'DELIVERY_EARNING',
        'amount': 25000,
        'deliveryId': '12345678-abcdef',
        'createdAt': '2026-01-01T12:00:00Z',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransactionHistoryView(
                rows: [row],
                loading: false,
                failed: false,
                hasNext: true,
                onMore: () {},
                onOpen: (_) => opened = true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Thu nhập giao hàng'), findsOneWidget);
      expect(find.textContaining('DELIVERY_EARNING'), findsNothing);
      expect(find.textContaining('12345678-abcdef'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
      await tester.tap(find.text('Thu nhập giao hàng'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty history uses the requested message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionHistoryView(
            rows: const [],
            loading: false,
            failed: false,
            hasNext: false,
            onMore: () {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Bạn chưa có giao dịch nào.'), findsOneWidget);
    await tester.tap(find.text('Hôm nay'));
    await tester.pump();
    expect(find.text('Không tìm thấy giao dịch phù hợp.'), findsOneWidget);
  });
}
