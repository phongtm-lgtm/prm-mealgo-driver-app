import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealgo_driver_app/api_client.dart';

void main() {
  test('uploads camera image to face verification with JWT', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/drivers/me/face-verification');
        expect(request.headers['Authorization'], 'Bearer driver-token');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(request.body, contains('name="image"'));
        expect(request.body, contains('filename="face.jpg"'));
        return http.Response(
          '{"success":true,"mode":"MOCK_ALWAYS_SUCCESS"}',
          200,
        );
      }),
    );
    api.token = 'driver-token';
    await api.verifyFace([1, 2, 3], 'face.jpg');
    api.close();
  });

  test('does not accept failed verification response', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{"success":false}', 200)),
    );
    await expectLater(
      api.verifyFace([1], 'face.jpg'),
      throwsA(isA<ApiException>()),
    );
    api.close();
  });

  test('sends bearer token and JSON to the real API path', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/drivers/me/online-status');
        expect(request.headers['Authorization'], 'Bearer driver-token');
        expect(jsonDecode(request.body), {'online': true});
        return http.Response('{"onlineStatus":"ONLINE"}', 200);
      }),
    );
    api.token = 'driver-token';
    expect(
      (await api.request('PUT', '/drivers/me/online-status', {
        'online': true,
      }))['onlineStatus'],
      'ONLINE',
    );
    api.close();
  });

  test('handles no current delivery (204)', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('', 204)),
    );
    expect(await api.request('GET', '/drivers/me/deliveries/current'), isNull);
    api.close();
  });

  test('surfaces business conflicts', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response('{"detail":"Order is not READY"}', 409),
      ),
    );
    await expectLater(
      api.request('POST', '/drivers/me/deliveries/id/confirm-pickup'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Order is not READY',
        ),
      ),
    );
    api.close();
  });

  test('expires authenticated session on 401', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('', 401)),
    );
    bool expired = false;
    api.token = 'expired';
    api.onUnauthorized = () => expired = true;
    await expectLater(
      api.request('GET', '/drivers/me'),
      throwsA(isA<ApiException>()),
    );
    expect(expired, isTrue);
    api.close();
  });
}
