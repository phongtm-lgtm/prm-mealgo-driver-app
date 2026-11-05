import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealgo_driver_app/api_client.dart';
import 'package:mealgo_driver_app/app/backend_repositories.dart';
import 'package:mealgo_driver_app/driver_store.dart';
import 'package:mealgo_driver_app/features/delivery/domain/delivery.dart';

void main() {
  test('maps server delivery to original UI without fabricating earnings', () {
    final store = DriverStore();
    final repositories = BackendRepositories(store);
    final order = repositories.mapOrder({
      'deliveryId': 'delivery-1', 'status': 'AT_DROPOFF',
      'restaurant': {'name': 'Quán A'}, 'pickup': {'address': 'Điểm A'},
      'recipient': {'name': 'Khách B'}, 'dropoff': {'address': 'Điểm B'},
      'items': [{'quantity': 2, 'name': 'Cơm'}],
      'payment': {'amountToCollect': 75000},
    });
    expect(order.id, 'delivery-1');
    expect(order.stage, DeliveryStage.atCustomer);
    expect(order.total, 75000);
    expect(order.item, '2 × Cơm');
    expect(order.fee, 0);
    store.dispose();
  });
  test('offers use assignment ID, not delivery ID', () {
    final store = DriverStore();
    final order = BackendRepositories(store).mapOrder({
      'assignmentId': 'assignment-1', 'deliveryId': 'delivery-1',
      'pickup': {'address': 'A'}, 'dropoff': {'address': 'B'},
    }, offer: true);
    expect(order.id, 'assignment-1');
    store.dispose();
  });

  test('refresh skips assignment IDs and polls load current server offers', () async {
    final requests = <http.Request>[];
    final oldOffer = {'assignmentId': 'assignment-1', 'deliveryId': 'delivery-1'};
    final newOffer = {
      'assignmentId': 'assignment-2',
      'deliveryId': 'delivery-2',
      'orderId': 'order-2',
      'restaurantName': 'Quán A',
    };
    final store = DriverStore(
      api: ApiClient(client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode(jsonEncode([newOffer])), 200);
      })),
    );
    addTearDown(store.dispose);
    store.offers = [oldOffer];
    final repo = BackendRepositories(store);
    final result = await repo.refreshOffers([repo.mapOrder(oldOffer, offer: true)]);
    expect(result.single.id, 'assignment-2');
    expect(result.single.orderId, 'order-2');
    expect(result.single.restaurant, 'Quán A');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/drivers/me/offers/refresh');
    expect(jsonDecode(requests.single.body), {
      'skippedAssignmentIds': ['assignment-1'],
    });
    expect((await repo.getAvailable()).single.id, 'assignment-2');
    expect(requests.last.method, 'GET');
    expect(requests.last.url.path, '/api/v1/drivers/me/offers');
  });
}
