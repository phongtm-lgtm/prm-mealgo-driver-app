import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/features/account/presentation/driver_profile_view.dart';

void main() {
  testWidgets('Profile displays real values and edit action on small phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var edited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DriverProfileView(
              name: 'Demo Driver',
              driverId: '12345678-abcd-1234-abcd-123456789012',
              phone: '0900000001',
              onEdit: () => edited = true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Demo Driver'), findsNWidgets(2));
    expect(find.text('0900000001'), findsOneWidget);
    expect(find.text('Chưa có thông tin'), findsNothing);
    await tester.ensureVisible(find.text('Chỉnh sửa thông tin'));
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    expect(edited, isTrue);
    expect(tester.takeException(), isNull);
  });
}
