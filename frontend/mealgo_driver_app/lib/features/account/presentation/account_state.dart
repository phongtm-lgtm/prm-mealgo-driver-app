import 'package:flutter/foundation.dart';

import '../domain/account_repository.dart';

/// Shared session state: account pages do not depend on delivery widgets.
class AccountState extends ChangeNotifier {
  AccountState(this.repository);
  final AccountDataRepository repository;
  Map<String, dynamic>? wallet;
  Map<String, dynamic>? earnings;
  final Map<String, List<Map<String, dynamic>>> lists = {};
  final Map<String, bool> hasNext = {};
  final Map<String, int> _pages = {};
  int unread = 0;
  int revision = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void invalidate() {
    revision++;
    _notify();
  }

  Future<void> loadWallet() async {
    wallet = await repository.wallet();
    _notify();
  }

  Future<void> loadEarnings(String period, String date) async {
    earnings = await repository.earnings(period, date);
    _notify();
  }

  Future<void> loadList(String resource, {bool more = false}) async {
    final page = more ? (_pages[resource] ?? 0) + 1 : 0;
    final response = await repository.accountList(resource, page);
    final rows = (response['items'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    lists[resource] = [if (more) ...?lists[resource], ...rows];
    _pages[resource] = page;
    hasNext[resource] = response['hasNext'] == true;
    if (resource == 'notifications') unread = await repository.unreadCount();
    _notify();
  }

  Future<void> read(String? id) async {
    await repository.markRead(id);
    for (final row in lists['notifications'] ?? <Map<String, dynamic>>[]) {
      if (id == null || row['id'] == id) row['read'] = true;
    }
    unread = await repository.unreadCount();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
