class WalletEntry {
  const WalletEntry(this.title, this.time, this.amount);
  final String title;
  final String time;
  final int amount;
}

class AccountSummary {
  const AccountSummary({
    required this.balance,
    required this.dailyEarnings,
    required this.weeklyEarnings,
    required this.monthlyEarnings,
    required this.entries,
  });
  final int balance;
  final int dailyEarnings;
  final int weeklyEarnings;
  final int monthlyEarnings;
  final List<WalletEntry> entries;
}

abstract interface class AccountRepository {
  Future<AccountSummary> getSummary();
}
