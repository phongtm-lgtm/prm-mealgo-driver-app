import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';

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
  int _period = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(widget.section.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [..._content(context)],
      ),
    ),
  );

  List<Widget> _content(BuildContext context) {
    if (const [
      AccountSection.earnings,
      AccountSection.wallet,
      AccountSection.transactions,
      AccountSection.notifications,
    ].contains(widget.section)) {
      return const [
        SectionCard(
          child: Text(
            'Chưa hỗ trợ tính năng này. Hệ thống chưa có API cung cấp dữ liệu.',
          ),
        ),
      ];
    }
    final c = widget.controller;
    final profile = c.profile!;
    final summary = c.summary!;
    switch (widget.section) {
      case AccountSection.profile:
        return [
          const Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              profile.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Thông tin cá nhân',
            child: Column(
              children: [
                InfoRow('Mã tài xế', profile.id),
                InfoRow('Số điện thoại', profile.phone),
                InfoRow('Phương tiện', profile.vehicle),
              ],
            ),
          ),
        ];
      case AccountSection.earnings:
        final amount =
            [
              summary.dailyEarnings,
              summary.weeklyEarnings,
              summary.monthlyEarnings,
            ][_period] +
            c.earnedToday;
        return [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Ngày')),
              ButtonSegment(value: 1, label: Text('Tuần')),
              ButtonSegment(value: 2, label: Text('Tháng')),
            ],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title:
                'Tổng thu nhập ${['hôm nay', 'tuần này', 'tháng này'][_period]}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(amount),
                  style: const TextStyle(
                    fontSize: 34,
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final height in [
                        45.0,
                        70.0,
                        54.0,
                        95.0,
                        65.0,
                        110.0,
                        80.0,
                      ])
                        Expanded(
                          child: Container(
                            height: height,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .8),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Biểu đồ minh họa • không phải dữ liệu thống kê thực tế',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SectionCard(
            child: Column(
              children: [
                InfoRow('Đơn hoàn thành trong ca', '${c.completedToday} đơn'),
                InfoRow(
                  'Thu nhập trong ca',
                  money(c.earnedToday),
                  color: AppColors.green,
                ),
              ],
            ),
          ),
        ];
      case AccountSection.wallet:
        return [
          SectionCard(
            title: 'Số dư khả dụng',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(summary.balance + c.earnedToday),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _walletNotice(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Nạp tiền'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _walletNotice(context),
                        icon: const Icon(Icons.account_balance),
                        label: const Text('Rút tiền'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionCard(
            title: 'Tài khoản liên kết',
            child: Text('Chưa hỗ trợ liên kết ngân hàng.'),
          ),
          ..._transactions(),
        ];
      case AccountSection.transactions:
        return _transactions();
      case AccountSection.orders:
        return [
          if (c.history.isEmpty)
            const SectionCard(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có lịch sử giao hàng.'),
              ),
            ),
          for (final order in c.history)
            SectionCard(
              title: order.restaurant,
              child: Column(
                children: [
                  InfoRow(order.id, order.stage.label),
                  InfoRow(
                    'Thu nhập',
                    money(order.stage.name == 'completed' ? order.fee : 0),
                    color: AppColors.green,
                  ),
                  if (order.stage.name == 'reported')
                    const Text(
                      'Đã gửi báo cáo giao thất bại',
                      style: TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
        ];
      case AccountSection.notifications:
        return [
          const SectionCard(
            title: 'Chào mừng đến MealGo Driver',
            child: Text(
              'Hoàn thành hồ sơ và bắt đầu ca làm việc để nhận đơn hàng.',
            ),
          ),
          SectionCard(
            title: 'Cập nhật ca làm việc',
            child: Text(
              'Bạn đã hoàn thành ${c.completedToday} đơn trong phiên này. Dữ liệu sẽ đặt lại khi khởi động ứng dụng.',
            ),
          ),
          if (c.autoLocked)
            const SectionCard(
              title: 'Tạm khóa nhận đơn tự động',
              child: Text('Nhận đơn tự động hiện không khả dụng.'),
            ),
        ];
    }
  }

  List<Widget> _transactions() => [
    for (final order in widget.controller.history.where(
      (o) => o.stage.name == 'completed',
    ))
      SectionCard(
        child: InfoRow(
          'Giao hàng • ${order.id}',
          '+${money(order.fee)}',
          color: AppColors.green,
        ),
      ),
    for (final entry in widget.controller.summary!.entries)
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(
              entry.title,
              '${entry.amount > 0 ? '+' : ''}${money(entry.amount)}',
              color: entry.amount > 0 ? AppColors.green : Colors.red,
            ),
            Text(
              entry.time,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
  ];

  void _walletNotice(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Chưa kết nối thanh toán'),
      content: const Text(
        'Chưa hỗ trợ nạp/rút tiền. Hệ thống chưa có API thanh toán.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );
}
