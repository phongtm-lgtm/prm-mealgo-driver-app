import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';
import 'account_state.dart';

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

  Future<void> _load({bool more = false}) async {
    if (!mounted || (_loading && more)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.section == AccountSection.profile) return;
      final a = account;
      if (a == null) {
        throw StateError('Cần đăng nhập máy chủ để xem dữ liệu tài khoản.');
      }
      switch (widget.section) {
        case AccountSection.profile:
          break;
        case AccountSection.earnings:
          await a.loadEarnings(_period, _dateString);
        case AccountSection.wallet:
          await a.loadWallet();
          await a.loadList(_resource, more: more);
        case AccountSection.transactions:
        case AccountSection.orders:
        case AccountSection.notifications:
          await a.loadList(_resource, more: more);
      }
    } catch (e) {
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
            .showSnackBar(SnackBar(content: Text('$e')));
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
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            SectionCard(
              child: Column(
                children: [
                  Text(_error!),
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
        SectionCard(title: 'Thông tin cá nhân', child: Text(profile?.id ?? '')),
      ];
    }
    if (a == null) return [];
    switch (widget.section) {
      case AccountSection.profile:
        final p = widget.controller.profile;
        if (p == null) return [];
        return [
          SectionCard(
            title: 'Thông tin cá nhân',
            child: Column(
              children: [
                InfoRow('Họ tên', p.name),
                InfoRow('Mã tài xế', p.id),
                InfoRow('Số điện thoại', p.phone),
                const Text(
                  'Số điện thoại liên hệ không thay đổi số đăng nhập.',
                ),
                TextButton(
                  onPressed: _editProfile,
                  child: const Text('Chỉnh sửa hồ sơ'),
                ),
              ],
            ),
          ),
        ];
      case AccountSection.earnings:
        final e = _loading || _error != null ? null : a.earnings;
        final chart = (e?['chart'] as List? ?? []);
        final max = chart.fold<double>(
          0,
          (v, row) => (row['earnings'] as num).toDouble() > v
              ? (row['earnings'] as num).toDouble()
              : v,
        );
        return [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'DAY', label: Text('Ngày')),
              ButtonSegment(value: 'WEEK', label: Text('Tuần')),
              ButtonSegment(value: 'MONTH', label: Text('Tháng')),
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
            SectionCard(
              title: '${e['fromDate']} — ${e['toDate']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    money((e['totalEarnings'] as num).round()),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InfoRow(
                    'Chuyến được ghi nhận',
                    '${e['completedDeliveries']}',
                  ),
                  if (e['earningsConfigured'] != true)
                    const Text(
                      'Chưa cấu hình tiền công. Không lấy tiền COD làm thu nhập.',
                    ),
                  const Text(
                    'Theo giờ Việt Nam. Không tính bù chuyến trước khi triển khai.',
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final row in chart)
                          SizedBox(
                            width: 72,
                            child: Column(
                              children: [
                                Tooltip(
                                  message: money(
                                    (row['earnings'] as num).round(),
                                  ),
                                  child: Container(
                                    width: 28,
                                    height: max == 0
                                        ? 2
                                        : 2 +
                                              98 *
                                                  (row['earnings'] as num) /
                                                  max,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                                Text((row['date'] as String).substring(5)),
                                Text(
                                  money((row['earnings'] as num).round()),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ];
      case AccountSection.wallet:
      case AccountSection.transactions:
      case AccountSection.orders:
      case AccountSection.notifications:
        final rows = a.lists[_resource] ?? [];
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
                    'Chưa hỗ trợ nạp/rút, ngân hàng hoặc đối soát COD.',
                  ),
                ],
              ),
            ),
          if (widget.section == AccountSection.notifications)
            Row(
              children: [
                Expanded(child: Text('${a.unread} thông báo chưa đọc')),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => _action(() => a.read(null)),
                  child: const Text('Đọc tất cả'),
                ),
              ],
            ),
          if (!_loading && _error == null && rows.isEmpty)
            const SectionCard(child: Text('Chưa có dữ liệu.')),
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
        child: ListTile(
          leading: Icon(
            row['read'] == true
                ? Icons.notifications_none
                : Icons.notifications_active,
          ),
          title: Text(row['title'] as String),
          subtitle: Text('${row['message']}\n${_time(row['createdAt'])}'),
          trailing: row['read'] == true ? null : const Text('Chưa đọc'),
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
        onTap: () => _action(() async {
          final detail = await account!.repository.accountDetail(
            _resource,
            (order ? row['deliveryId'] : row['id']) as String,
          );
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                order ? 'Chi tiết chuyến giao' : 'Chi tiết giao dịch',
              ),
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
                            'COD cần thu: ${money((detail['payment']?['amountToCollect'] as num? ?? 0).round())}',
                          ),
                          Text('Cập nhật: ${_time(detail['updatedAt'])}'),
                          const Text(
                            'Tiền công xem trong giao dịch ví; COD không phải thu nhập.',
                          ),
                        ]
                      : [
                          Text('${detail['description']}'),
                          Text('Mã: ${detail['id']}'),
                          Text(
                            'Số tiền: ${money((detail['amount'] as num).round())}',
                          ),
                          Text(
                            'Số dư sau giao dịch: ${money((detail['balanceAfter'] as num).round())}',
                          ),
                          Text('Chuyến: ${detail['deliveryId']}'),
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
        }),
      ),
    );
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse('$value')
        ?.toUtc()
        .add(const Duration(hours: 7));
    return date == null
        ? ''
        : '${date.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} (giờ VN)';
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
