import '../domain/account_repository.dart';

class MockAccountRepository implements AccountRepository {
  @override
  Future<AccountSummary> getSummary() async => const AccountSummary(
    balance: 350000,
    dailyEarnings: 185000,
    weeklyEarnings: 1850000,
    monthlyEarnings: 7150000,
    entries: [
      WalletEntry('Thu nhập giao hàng • MG-1020', 'Hôm nay, 10:42', 24000),
      WalletEntry('Thu nhập giao hàng • MG-1019', 'Hôm nay, 09:15', 18000),
      WalletEntry('Rút tiền về ngân hàng', 'Hôm qua, 18:30', -50000),
      WalletEntry('Thưởng hoàn thành ca', 'Hôm qua, 17:00', 30000),
    ],
  );
}
