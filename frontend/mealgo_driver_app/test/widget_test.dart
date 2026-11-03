import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/app.dart';
import 'package:mealgo_driver_app/app/app_dependencies.dart';
import 'package:mealgo_driver_app/features/home/presentation/driver_controller.dart';
import 'package:mealgo_driver_app/features/driver/presentation/settings_page.dart';
import 'package:mealgo_driver_app/shared/widgets/app_widgets.dart';

void main() {
  testWidgets('Slide action fills its track and submits at the visible edge', (
    tester,
  ) async {
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SlideAction(
                    label: 'Sẵn sàng làm việc »',
                    onSubmit: () => submissions++,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final handle = find.byIcon(Icons.keyboard_double_arrow_right);
    final track = find.byType(SlideAction);
    final trackRect = tester.getRect(track);
    final handleCenter = tester.getCenter(handle);
    final visibleTravel = trackRect.right - 4 - 27 - handleCenter.dx;
    expect(
      tester
          .getSize(find.descendant(of: track, matching: find.byType(Stack)))
          .width,
      400,
    );
    await tester.drag(handle, Offset(visibleTravel, 0));
    await tester.pumpAndSettle();
    expect(submissions, 1);
  });

  testWidgets('Settings page renders editable mock limits', (tester) async {
    final controller = DriverController(AppDependencies.mock());
    // Wait outside the fake clock for repository initialization.
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Khoảng cách giao hàng'), findsOneWidget);
    expect(find.text('Số lượng món tối đa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Automatic offer times out after 15 seconds', (tester) async {
    final controller = DriverController(AppDependencies.mock());
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.setOnline(true);
      await controller.saveSettings(
        controller.settings.copyWith(autoAccept: true),
      );
    });
    expect(controller.simulateOffer(), isTrue);
    await tester.pump(const Duration(seconds: 15));
    expect(controller.offer, isNull);
    expect(controller.rejectedOffers, 1);
    expect(controller.error, contains('15 giây'));
    controller.dispose();
  });

  testWidgets('Shift control appears only in the sidebar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MealGoDriverApp(dependencies: AppDependencies.mock()),
    );
    await tester.pumpAndSettle();

    expect(find.text('● OFFLINE'), findsOneWidget);
    expect(find.text('Sẵn sàng làm việc »'), findsNothing);
    expect(find.text('Bắt đầu ca'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Drawer), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu ca'), findsOneWidget);
  });

  testWidgets('Drawer opens profile page', (tester) async {
    await tester.pumpWidget(
      MealGoDriverApp(dependencies: AppDependencies.mock()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin tài xế'));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('MG-20489'), findsOneWidget);
  });

  testWidgets('Dashboard fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MealGoDriverApp(dependencies: AppDependencies.mock()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
