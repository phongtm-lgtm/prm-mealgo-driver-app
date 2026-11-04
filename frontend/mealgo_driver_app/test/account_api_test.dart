import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mealgo_driver_app/api_client.dart';
import 'package:mealgo_driver_app/driver_store.dart';
import 'package:mealgo_driver_app/app/backend_repositories.dart';
import 'package:mealgo_driver_app/features/driver/domain/driver.dart';
import 'package:mealgo_driver_app/features/account/presentation/account_state.dart';
import 'package:mealgo_driver_app/features/account/presentation/account_page.dart';
import 'package:mealgo_driver_app/features/home/presentation/driver_controller.dart';
import 'package:mealgo_driver_app/app/app_dependencies.dart';

void main() {
  testWidgets('notifications show local time and disable read all when none unread', (tester) async {
    final api = ApiClient(client: MockClient((request) async => http.Response(jsonEncode(
      request.url.path.endsWith('unread-count') ? {'count': 0} : {
        'items': [{'id': 'notice', 'title': 'Giao hàng thành công', 'message': 'Giao hàng thành công! Tiền công của đơn này đang được cập nhật.', 'read': true, 'createdAt': '2026-11-04T03:07:00Z'}], 'hasNext': false,
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
    final controller = DriverController(AppDependencies.backend(DriverStore(api: api)));
    await tester.pumpWidget(MaterialApp(home: AccountPage(controller: controller, section: AccountSection.notifications)));
    await tester.pumpAndSettle();
    expect(find.textContaining('10:07 · 04/11/2026'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Đọc tất cả')).onPressed, isNull);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    api.close();
  });
  testWidgets(
    'wallet renders server balance without fabricating payment controls',
    (tester) async {
      final api = ApiClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/wallet')
                  ? {
                      'balance': 15000,
                      'earningsConfigured': false,
                      'currency': 'VND',
                    }
                  : {'items': [], 'hasNext': false},
            ),
            200,
          ),
        ),
      );
      final controller = DriverController(
        AppDependencies.backend(DriverStore(api: api)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AccountPage(
            controller: controller,
            section: AccountSection.wallet,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Số dư tiền công'), findsOneWidget);
      expect(
        find.text('Chưa có mức tiền công cho chuyến giao mới.'),
        findsOneWidget,
      );
      expect(
        find.text('Các giao dịch của bạn sẽ xuất hiện tại đây.'),
        findsOneWidget,
      );
      expect(find.text('15.000đ'), findsOneWidget);
      expect(find.text('Số dư có thể rút'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Rút tiền chưa khả dụng'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Nạp tiền'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      api.close();
    },
  );
  test(
    'settings load server defaults and save both persisted resources',
    () async {
      final writes = <String, dynamic>{};
      final api = ApiClient(
        client: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'PUT') writes[path] = jsonDecode(request.body);
          return http.Response(
            jsonEncode(
              path.endsWith('order-settings')
                  ? {
                      'autoAcceptEnabled': false,
                      'maxDeliveryDistanceKm': 100,
                      'maxItemQuantity': 5000,
                      'maxRestaurantAdvanceAmount': 0,
                    }
                  : {'inAppNotificationsEnabled': true},
            ),
            200,
          );
        }),
      );
      final repository = BackendRepositories(DriverStore(api: api));
      final settings = await repository.getSettings();
      expect(settings.maxDistance, 100);
      expect(settings.maxItems, 5000);
      await repository.saveSettings(
        const DriverSettings(
          maxDistance: 8,
          maxItems: 10,
          notifications: false,
        ),
      );
      expect(
        writes['/api/v1/drivers/me/order-settings']['maxDeliveryDistanceKm'],
        8,
      );
      expect(
        writes['/api/v1/drivers/me/app-settings']['inAppNotificationsEnabled'],
        false,
      );
      api.close();
    },
  );

  test(
    'account state paginates, reads notifications and uses earnings endpoint',
    () async {
      var unread = 2;
      final api = ApiClient(
        client: MockClient((request) async {
          final path = request.url.path;
          Object body;
          if (path.endsWith('unread-count')) {
            body = {'count': unread};
          } else if (request.method == 'PATCH') {
            unread = 0;
            return http.Response('', 204);
          } else if (path.endsWith('earnings')) {
            expect(request.url.queryParameters['period'], 'WEEK');
            expect(request.url.queryParameters['date'], '2026-11-03');
            body = {'totalEarnings': 15000, 'chart': []};
          } else {
            final page = request.url.queryParameters['page'];
            body = {
              'items': [
                {'id': page, 'read': false},
              ],
              'hasNext': page == '0',
            };
          }
          return http.Response(jsonEncode(body), 200);
        }),
      );
      final state = AccountState(BackendRepositories(DriverStore(api: api)));
      await state.loadList('notifications');
      expect(state.unread, 2);
      expect(state.hasNext['notifications'], true);
      await state.loadList('notifications', more: true);
      expect(state.lists['notifications']!.length, 2);
      expect(state.hasNext['notifications'], false);
      await state.read(null);
      expect(state.unread, 0);
      expect(
        state.lists['notifications']!.every((row) => row['read'] == true),
        true,
      );
      await state.loadEarnings('WEEK', '2026-11-03');
      expect(state.earnings!['totalEarnings'], 15000);
      await state.loadList('notifications');
      expect(state.lists['notifications']!.length, 1);
      state.dispose();
      api.close();
    },
  );
}
