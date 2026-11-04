import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/driver_store.dart';
import 'package:mealgo_driver_app/features/home/presentation/registration_page.dart';
import 'package:mealgo_driver_app/features/home/presentation/widgets/onboarding_components.dart';

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
        find.text(
          'Nhập số di động Việt Nam bắt đầu bằng 03, 05, 07, 08, 09 hoặc +84 tương ứng.',
        ),
        findsOneWidget,
      );
      await tester.enterText(fields.at(0), '+84901234567');
      await tester.enterText(fields.at(1), 'short');
      await tester.pump();
      expect(find.text('Mật khẩu cần từ 8 đến 72 ký tự.'), findsOneWidget);
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.enterText(fields.at(2), 'different');
      await tester.pump();
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      await tester.enterText(fields.at(2), 'Password123!');
      await tester.pump();
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsNothing);
      await tester.enterText(fields.at(1), 'NewPassword123!');
      await tester.pump();
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.byType(AppCheckbox),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets(
    'Small screen keeps CTA visible above keyboard and legal links separate',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = DriverStore();
      await tester.pumpWidget(
        MaterialApp(home: RegistrationPage(store: store)),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(AppCheckbox),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Chính sách bảo mật'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Điều khoản sử dụng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nội dung chính thức'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      await tester.tap(find.text('Chính sách bảo mật'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nội dung chính thức'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Tiếp tục');
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
