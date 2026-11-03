import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealgo_driver_app/api_client.dart';
import 'package:mealgo_driver_app/driver_store.dart';
import 'package:mealgo_driver_app/features/home/presentation/login_page.dart';

void main() {
  testWidgets('login screen sends phoneNumber instead of username', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'detail': 'Số điện thoại hoặc mật khẩu không đúng'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final store = DriverStore(api: api);
    await tester.pumpWidget(MaterialApp(home: LoginPage(store: store)));
    expect(find.text('Số điện thoại'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '0900000001');
    await tester.enterText(find.byType(TextField).last, 'incorrect');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(submitted, {'phoneNumber': '0900000001', 'password': 'incorrect'});
    expect(store.authenticated, isFalse);
    expect(store.error, contains('Số điện thoại hoặc mật khẩu không đúng'));
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  test('invalid phone is rejected before making an API call', () async {
    var calls = 0;
    final store = DriverStore(
      api: ApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 500);
        }),
      ),
    );
    await store.login('driver.demo', 'Mealgo123!');
    expect(calls, 0);
    expect(store.error, contains('không hợp lệ'));
    expect(store.authenticated, isFalse);
    store.dispose();
  });
}
