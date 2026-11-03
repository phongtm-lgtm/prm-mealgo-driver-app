import 'package:flutter_test/flutter_test.dart';
import 'package:mealgo_driver_app/app/app_dependencies.dart';
import 'package:mealgo_driver_app/features/delivery/domain/delivery.dart';
import 'package:mealgo_driver_app/features/home/presentation/driver_controller.dart';

void main() {
  late DriverController controller;

  setUp(() async {
    controller = DriverController(AppDependencies.mock());
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  test(
    'Requires shift before accepting and rejects concurrent orders',
    () async {
      final first = controller.available.first;
      expect(await controller.accept(first), isFalse);
      await controller.setOnline(true);
      expect(await controller.accept(first), isTrue);
      expect(await controller.accept(controller.available.first), isFalse);
      expect(controller.activeOrder!.id, first.id);
      expect(await controller.setOnline(false), isFalse);
      expect(controller.online, isTrue);
    },
  );

  test('Completes all four delivery transitions and credits once', () async {
    await controller.setOnline(true);
    final order = controller.available.first;
    await controller.accept(order);
    for (var i = 0; i < 4; i++) {
      expect(await controller.advance(), isTrue);
    }
    expect(controller.activeOrder, isNull);
    expect(controller.completedToday, 1);
    expect(controller.earnedToday, order.fee);
    expect(controller.history.single.stage, DeliveryStage.completed);
    await controller.advance();
    expect(controller.earnedToday, order.fee);
  });

  test(
    'Cannot reject after pickup; report requires arrival and evidence',
    () async {
      await controller.setOnline(true);
      final order = controller.available.first;
      await controller.accept(order);
      await controller.advance();
      await controller.advance();
      expect(await controller.rejectActive('Lý do cá nhân'), isFalse);
      final report = DeliveryReport(
        orderId: order.id,
        reason: 'Không liên hệ được',
        note: 'Đã gọi và chờ',
        evidence: 'mock://photo',
      );
      expect(await controller.reportFailure(report), isFalse);
      await controller.advance();
      expect(await controller.reportFailure(report), isTrue);
      expect(controller.history.single.stage, DeliveryStage.reported);
      expect(controller.earnedToday, 0);
    },
  );

  test(
    'Four rejected offers lock auto mode but do not lock free pick',
    () async {
      await controller.setOnline(true);
      await controller.saveSettings(
        controller.settings.copyWith(autoAccept: true),
      );
      for (var i = 0; i < 4; i++) {
        expect(controller.simulateOffer(), isTrue);
        controller.rejectOffer();
      }
      expect(controller.autoLocked, isTrue);
      expect(controller.simulateOffer(), isFalse);
      expect(await controller.accept(controller.available.first), isTrue);
    },
  );

  test('Filters requests by distance and preserves settings', () async {
    await controller.saveSettings(controller.settings.copyWith(maxDistance: 2));
    expect(controller.available.length, 1);
    expect(controller.settings.maxDistance, 2);
  });
}
