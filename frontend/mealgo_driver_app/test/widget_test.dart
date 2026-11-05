import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/app.dart';
import 'package:mealgo_driver_app/features/home/presentation/home_page.dart';
import 'package:mealgo_driver_app/app/app_dependencies.dart';
import 'package:mealgo_driver_app/features/home/presentation/driver_controller.dart';
import 'package:mealgo_driver_app/features/driver/presentation/settings_page.dart';
import 'package:mealgo_driver_app/shared/widgets/app_widgets.dart';

void main() {
  testWidgets('Free-Pick refresh skips only the displayed request', (
    tester,
  ) async {
    final controller = DriverController(AppDependencies.mock());
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.setOnline(true);
    });
    addTearDown(controller.dispose);
    final orders = controller.available;
    controller.selectOrder(orders[1]);
    await tester.pumpWidget(MaterialApp(home: HomePage(controller: controller)));

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.bySemanticsLabel('Đang tìm đơn mới'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(controller.selectedOrder, isNull);
    expect(controller.available.map((o) => o.id), [orders[0].id, orders[2].id]);
    expect(find.text('2 đơn khả dụng'), findsOneWidget);
    expect(find.textContaining('#${orders[0].id}'), findsOneWidget);
    expect(find.textContaining('#${orders[1].id}'), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(controller.available.single.id, orders[2].id);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('0 đơn khả dụng'), findsOneWidget);
    await tester.tap(find.byTooltip('Tìm đơn mới'));
    await tester.pumpAndSettle();
    expect(controller.available, isEmpty);
  });

  testWidgets('Logout requires confirmation and can be cancelled', (
    tester,
  ) async {
    final controller = DriverController(AppDependencies.mock());
    await tester.runAsync(controller.initialize);
    var logoutCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          controller: controller,
          onLogout: () async {
            logoutCount++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Đăng xuất'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(logoutCount, 0);
    await tester.tap(find.text('Ở lại'));
    await tester.pumpAndSettle();
    expect(logoutCount, 0);
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 250,
      scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(logoutCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
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
    expect(find.text('Khoảng cách nhận đơn'), findsOneWidget);
    expect(find.text('Chỉ nhận đơn trong phạm vi bạn chọn.'), findsOneWidget);
    expect(find.text('Số món tối đa trong một đơn'), findsOneWidget);
    expect(find.text('Số tiền cần ứng tối đa'), findsOneWidget);
    expect(find.textContaining('máy chủ'), findsNothing);
    expect(find.textContaining('COD'), findsNothing);
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

  testWidgets('Shift control appears only in the sidebar', (tester) async {
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
