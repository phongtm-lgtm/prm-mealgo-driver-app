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

/// Persisted account data. All identifiers are scoped to the authenticated driver.
abstract interface class AccountDataRepository {
  Future<Map<String, dynamic>> wallet();
  Future<Map<String, dynamic>> earnings(String period, String date);
  Future<Map<String, dynamic>> accountList(String resource, int page);
  Future<Map<String, dynamic>> accountDetail(String resource, String id);
  Future<int> unreadCount();
  Future<void> markRead(String? id);
  Future<DriverProfileData> updateProfile(String name, String phone);
}

typedef DriverProfileData = Map<String, dynamic>;
