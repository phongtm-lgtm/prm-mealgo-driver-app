import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';
import 'account_state.dart';
import 'order_history_view.dart';
import 'transaction_history_view.dart';
import 'wallet_view.dart';
import 'earnings_view.dart';
import 'driver_profile_view.dart';

enum AccountSection {
  profile('Thông tin tài xế'),
  earnings('Thu nhập'),
  wallet('Ví của tôi'),
  transactions('Lịch sử giao dịch'),
  orders('Lịch sử đơn hàng'),
  notifications('Thông báo');

  const AccountSection(this.title);
  final String title;
}

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.controller,
    required this.section,
  });
  final DriverController controller;
  final AccountSection section;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  AccountState? get account => widget.controller.account;
  String _period = 'DAY';
  DateTime _date = DateTime.now().toUtc().add(const Duration(hours: 7));
  bool _loading = true;
  String? _error;
  int _revision = 0;
  Map<String, dynamic>? _todayEarnings;
  String get _dateString =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
  String get _resource => switch (widget.section) {
    AccountSection.orders => 'deliveries/history',
    AccountSection.notifications => 'notifications',
    _ => 'wallet/transactions',
  };

  @override
  void initState() {
    super.initState();
    _revision = account?.revision ?? 0;
    account?.addListener(_changed);
    _load();
  }

  void _changed() {
    if (!mounted) return;
    if (_revision != account!.revision) {
      _revision = account!.revision;
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load({bool more = false, bool refresh = false}) async {
    if (!mounted || (_loading && more)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.section == AccountSection.profile) return;
      final a = account;
      if (a == null) {
        throw StateError('Vui lòng đăng nhập để xem thông tin tài khoản.');
      }
      switch (widget.section) {
        case AccountSection.profile:
          break;
        case AccountSection.earnings:
          await a.loadEarnings(_period, _dateString);
        case AccountSection.wallet:
          await a.loadWallet();
          await a.loadList(_resource, more: more);
          final now = DateTime.now().toUtc().add(const Duration(hours: 7));
          final date =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          try {
            _todayEarnings = await a.repository.earnings('DAY', date);
          } catch (_) {
            _todayEarnings = null;
          }
        case AccountSection.transactions:
        case AccountSection.orders:
        case AccountSection.notifications:
          await a.loadList(_resource, more: more);
      }
    } catch (e) {
      if (mounted &&
          refresh &&
          (widget.section == AccountSection.transactions ||
              widget.section == AccountSection.notifications)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.section == AccountSection.notifications
                  ? 'Chưa thể cập nhật thông báo. Vui lòng thử lại.'
                  : 'Không thể cập nhật giao dịch. Hãy thử lại nhé.',
            ),
          ),
        );
        return;
      }
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.section == AccountSection.notifications
              ? 'Chưa thể cập nhật thông báo. Vui lòng thử lại.' : '$e')));
      }
    }
  }

  @override
  void dispose() {
    account?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.section.title),
      actions: [
        IconButton(
          onPressed: _loading ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            SectionCard(
              child: Column(
                children: [
                  Text(
                    widget.section == AccountSection.transactions
                        ? 'Chưa thể tải lịch sử giao dịch. Vui lòng thử lại.'
                        : widget.section == AccountSection.wallet
                        ? 'Chưa thể tải thông tin ví. Vui lòng thử lại.'
                        : widget.section == AccountSection.orders
                        ? 'Chưa thể tải lịch sử đơn hàng. Vui lòng thử lại.'
                        : widget.section == AccountSection.notifications
                        ? 'Chưa thể tải thông báo. Vui lòng thử lại.'
                        : _error!,
                  ),
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ..._content(),
        ],
      ),
    ),
  );

  List<Widget> _content() {
    final a = account;
    if (a == null && widget.section == AccountSection.profile) {
      final profile = widget.controller.profile;
      return [
        if (profile != null)
          DriverProfileView(
            name: profile.name,
            driverId: profile.id,
            phone: profile.phone,
          ),
      ];
    }
    if (a == null) return [];
    switch (widget.section) {
      case AccountSection.profile:
        final p = widget.controller.profile;
        if (p == null) return [];
        return [
          DriverProfileView(
            name: p.name,
            driverId: p.id,
            phone: p.phone,
            onEdit: _editProfile,
          ),
        ];
      case AccountSection.earnings:
        final e = _loading || _error != null ? null : a.earnings;
        return [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'DAY', label: Text('Theo ngày')),
              ButtonSegment(value: 'WEEK', label: Text('Theo tuần')),
              ButtonSegment(value: 'MONTH', label: Text('Theo tháng')),
            ],
            selected: {_period},
            onSelectionChanged: _loading
                ? null
                : (v) {
                    setState(() => _period = v.first);
                    _load();
                  },
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(_dateString),
            onPressed: _loading
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) {
                      setState(() => _date = date);
                      _load();
                    }
                  },
          ),
          if (e != null)
            EarningsView(
              data: e,
              onTransactions: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AccountPage(
                    controller: widget.controller,
                    section: AccountSection.transactions,
                  ),
                ),
              ),
            ),
        ];
      case AccountSection.wallet:
      case AccountSection.transactions:
      case AccountSection.orders:
      case AccountSection.notifications:
        final rows = a.lists[_resource] ?? [];
        if (widget.section == AccountSection.wallet) {
          return [
            WalletView(
              wallet: a.wallet,
              earnings: _todayEarnings,
              rows: rows,
              loading: _loading,
              failed: _error != null,
              onOpen: _openDetail,
              onAll: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AccountPage(
                    controller: widget.controller,
                    section: AccountSection.transactions,
                  ),
                ),
              ),
            ),
          ];
        }
        if (widget.section == AccountSection.transactions) {
          return [
            TransactionHistoryView(
              rows: rows,
              loading: _loading,
              failed: _error != null,
              hasNext: a.hasNext[_resource] == true,
              onMore: () => _load(more: true),
              onOpen: _openDetail,
            ),
          ];
        }
        if (widget.section == AccountSection.orders) {
          return [
            OrderHistoryView(
              rows: rows,
              loading: _loading,
              failed: _error != null,
              hasNext: a.hasNext[_resource] == true,
              onMore: () => _load(more: true),
              onOpen: (row) => _openDetail(row),
            ),
          ];
        }
        return [
          if (widget.section == AccountSection.wallet && a.wallet != null)
            SectionCard(
              title: 'Số dư tiền công',
              child: Column(
                children: [
                  Text(
                    money((a.wallet!['balance'] as num).round()),
                    style: const TextStyle(fontSize: 32),
                  ),
                  if (a.wallet!['earningsConfigured'] != true)
                    const Text('Tiền công chưa được cấu hình.'),
                  const Text(
                    'Bạn chưa thể nạp, rút tiền hoặc liên kết ngân hàng tại đây.',
                  ),
                ],
              ),
            ),
          if (widget.section == AccountSection.notifications)
            Row(
              children: [
                Expanded(child: Text('${a.unread} thông báo chưa đọc')),
                TextButton(
                  onPressed: _loading || a.unread == 0
                      ? null
                      : () => _action(() => a.read(null)),
                  child: const Text('Đọc tất cả'),
                ),
              ],
            ),
          if (!_loading && _error == null && rows.isEmpty)
            const SectionCard(child: Text('Chưa có thông tin để hiển thị.')),
          for (final row in rows) _row(row),
          if (a.hasNext[_resource] == true)
            TextButton(
              onPressed: _loading ? null : () => _load(more: true),
              child: const Text('Tải thêm'),
            ),
        ];
    }
  }

  Widget _row(Map<String, dynamic> row) {
    if (widget.section == AccountSection.notifications)
      return Card(
        elevation: 0,
        color: row['read'] == true
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primary.withValues(alpha: .07),
        child: ListTile(
          leading: Icon(
            row['read'] == true
                ? Icons.notifications_none
                : Icons.notifications_active,
          ),
          title: Text(
            row['title'] as String,
            style: TextStyle(
              fontWeight: row['read'] == true
                  ? FontWeight.w500
                  : FontWeight.w700,
            ),
          ),
          subtitle: Text('${row['message']}\n${_time(row['createdAt'])}'),
          trailing: row['read'] == true
              ? null
              : Icon(
                  Icons.circle,
                  size: 9,
                  color: Theme.of(context).colorScheme.primary,
                ),
          onTap: () => _action(() => account!.read(row['id'] as String)),
        ),
      );
    final order = widget.section == AccountSection.orders;
    return Card(
      child: ListTile(
        title: Text(
          order
              ? '${row['restaurant']?['name'] ?? 'Chuyến giao'}'
              : '${row['description']}',
        ),
        subtitle: Text(
          order
              ? '${row['deliveryId']}\n${_status(row['status'])}'
              : '${money((row['amount'] as num).round())}\n${_time(row['createdAt'])}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openDetail(row),
      ),
    );
  }

  Future<void> _openDetail(Map<String, dynamic> row) {
    final order = widget.section == AccountSection.orders;
    return _action(() async {
      final detail = await account!.repository.accountDetail(
        _resource,
        (order ? row['deliveryId'] : row['id']) as String,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(order ? 'Chi tiết chuyến giao' : 'Chi tiết giao dịch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order
                  ? [
                      Text('Mã chuyến: ${detail['deliveryId']}'),
                      Text('Trạng thái: ${_status(detail['status'])}'),
                      Text('Quán: ${detail['restaurant']?['name']}'),
                      Text('Lấy hàng: ${detail['pickup']?['address']}'),
                      Text('Giao đến: ${detail['dropoff']?['address']}'),
                      Text(
                        'Người nhận: ${detail['recipient']?['name']} • ${detail['recipient']?['phone']}',
                      ),
                      for (final item in detail['items'] as List? ?? [])
                        Text('${item['quantity']} × ${item['name']}'),
                      Text(
                        'Tiền cần thu từ khách: ${money((detail['payment']?['amountToCollect'] as num? ?? 0).round())}',
                      ),
                      Text('Cập nhật: ${_time(detail['updatedAt'])}'),
                      const Text(
                        'Xem tiền công trong giao dịch ví. Tiền thu hộ không tính vào thu nhập.',
                      ),
                    ]
                  : [
                      Text(transactionTitle(detail)),
                      Text(
                        'Số tiền: ${money((detail['amount'] as num).round())}',
                      ),
                      Text(
                        'Số dư sau giao dịch: ${money((detail['balanceAfter'] as num).round())}',
                      ),
                      if (detail['deliveryId'] != null)
                        Text(
                          'Mã chuyến: ${shortTransactionId(detail['deliveryId'])}',
                        ),
                      Text(_time(detail['createdAt'])),
                    ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    });
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse('$value')
        ?.toUtc()
        .add(const Duration(hours: 7));
    return date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} · ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _status(dynamic value) => switch (value) {
    'DELIVERED' => 'Giao thành công',
    'CANCELLED' => 'Đã hủy do quán đóng cửa',
    'FAILED' => 'Giao thất bại',
    _ => '$value',
  };

  Future<void> _editProfile() async {
    final p = widget.controller.profile!;
    final name = TextEditingController(text: p.name);
    final phone = TextEditingController(text: p.phone);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Họ tên'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Điện thoại liên hệ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      final ok = await widget.controller.updateProfile(
        name.text.trim(),
        phone.text.trim(),
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Đã lưu hồ sơ'
                  : widget.controller.error ?? 'Không lưu được hồ sơ',
            ),
          ),
        );
      }
    }
    name.dispose();
    phone.dispose();
  }
}
