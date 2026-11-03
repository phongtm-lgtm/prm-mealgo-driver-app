import '../features/account/data/mock_account_repository.dart';
import '../features/account/domain/account_repository.dart';
import '../features/delivery/data/mock_delivery_repository.dart';
import '../features/delivery/domain/delivery.dart';
import '../features/driver/data/mock_driver_repository.dart';
import '../features/driver/domain/driver.dart';
import '../driver_store.dart';
import 'backend_repositories.dart';

/// Composition root: replace mock implementations here when APIs are ready.
class AppDependencies {
  const AppDependencies({
    required this.driver,
    required this.delivery,
    required this.account,
  });

  factory AppDependencies.mock() => AppDependencies(
    driver: MockDriverRepository(),
    delivery: MockDeliveryRepository(),
    account: MockAccountRepository(),
  );

  factory AppDependencies.backend(DriverStore store) {
    final repositories = BackendRepositories(store);
    return AppDependencies(
      driver: repositories,
      delivery: repositories,
      account: repositories,
    );
  }

  final DriverRepository driver;
  final DeliveryRepository delivery;
  final AccountRepository account;
}
