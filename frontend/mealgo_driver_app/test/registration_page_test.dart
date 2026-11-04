import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/driver_store.dart';
import 'package:mealgo_driver_app/features/home/presentation/registration_page.dart';

void main() {
  testWidgets(
    'Registration validates inputs inline and rechecks confirmation',
    (tester) async {
      final store = DriverStore();
      await tester.pumpWidget(
        MaterialApp(home: RegistrationPage(store: store)),
      );
      final fields = find.byType(TextFormField);
      expect(find.text('Vui lòng nhập mật khẩu.'), findsNothing);
      await tester.enterText(fields.at(0), '123');
      await tester.pump();
      expect(
        find.text('Nhập số di động Việt Nam, bắt đầu bằng 0 hoặc +84.'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(0), '+84901234567');
      await tester.enterText(fields.at(1), 'short');
      await tester.pump();
      expect(find.text('Mật khẩu từ 8–72 ký tự'), findsOneWidget);
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.enterText(fields.at(2), 'different');
      await tester.pump();
      expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
      await tester.enterText(fields.at(2), 'Password123!');
      await tester.pump();
      expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsNothing);
      await tester.enterText(fields.at(1), 'NewPassword123!');
      await tester.pump();
      expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
  testWidgets('Continue is enabled only while consent is checked', (
    tester,
  ) async {
    final store = DriverStore();
    await tester.pumpWidget(MaterialApp(home: RegistrationPage(store: store)));
    final button = find.widgetWithText(FilledButton, 'Tiếp tục');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
