import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/features/home/presentation/face_verification_page.dart';

void main() {
  testWidgets(
    'Face onboarding fits small screens without opening camera automatically',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var sent = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FaceVerificationPage(
            verify: (_, _) async {
              sent = true;
            },
          ),
        ),
      );
      expect(find.text('Xác minh trước ca làm'), findsOneWidget);
      expect(find.text('Xác nhận khuôn mặt'), findsOneWidget);
      expect(find.text('Đặt khuôn mặt trong khung hình'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Mở camera'), findsOneWidget);
      expect(sent, isFalse);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bản thử nghiệm'),
        findsNothing,
      );
      expect(find.text('Mở camera').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Back returns false without submitting a photo', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        FaceVerificationPage(verify: (_, _) async {}),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Quay lại'), findsNothing);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
