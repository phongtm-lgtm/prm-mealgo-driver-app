import 'package:flutter_test/flutter_test.dart';
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
}
