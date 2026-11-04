import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import 'transaction_history_view.dart';

class WalletView extends StatelessWidget {
  const WalletView({
    super.key,
    required this.wallet,
    required this.earnings,
    required this.rows,
    required this.loading,
    required this.failed,
    required this.onOpen,
    required this.onAll,
  });
  final Map<String, dynamic>? wallet, earnings;
  final List<Map<String, dynamic>> rows;
  final bool loading, failed;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback onAll;

  String _money(num amount) =>
      money(amount.round()).replaceAll(RegExp(r'\s'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = wallet?['balance'] as num?;
    final recent = [...rows]
      ..sort(
        (a, b) => (DateTime.tryParse('${b['createdAt']}') ?? DateTime.utc(1970))
            .compareTo(
              DateTime.tryParse('${a['createdAt']}') ?? DateTime.utc(1970),
            ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Số dư tiền công',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                loading || failed || balance == null ? '—' : _money(balance),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tiền công đã được ghi nhận trong ví.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Color(0xFF333333)),
                    foregroundColor: WidgetStatePropertyAll(Colors.white70),
                  ),
                  child: Text('Rút tiền chưa khả dụng'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn chưa thể rút tiền hoặc liên kết ngân hàng tại đây.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!loading && !failed && earnings?['totalEarnings'] is num)
          _card(context, Icons.trending_up, 'Thu nhập hôm nay', [
            Text(
              _money(earnings!['totalEarnings'] as num),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text('Theo giờ Việt Nam. Không phải số dư có thể rút.'),
          ]),
        if (!loading && !failed && wallet?['earningsConfigured'] == false)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Chưa có mức tiền công cho chuyến giao mới.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        _card(context, Icons.info_outline, 'Tiền thu hộ cần đối soát', const [
          Text('Chưa có thông tin đối soát tiền thu hộ trong ứng dụng.'),
          SizedBox(height: 8),
          Text(
            'Tiền bạn thu hộ từ khách không phải thu nhập và không được tính vào số dư tiền công.',
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              'Giao dịch gần đây',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(onPressed: onAll, child: const Text('Xem tất cả')),
          ],
        ),
        if (!loading && !failed && rows.isEmpty)
          _card(
            context,
            Icons.receipt_long_outlined,
            'Lịch sử giao dịch',
            const [Text('Các giao dịch của bạn sẽ xuất hiện tại đây.')],
          ),
        if (!failed)
          for (final row in recent.take(5)) _transaction(context, row),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    IconData icon,
    String title,
    List<Widget> children,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _transaction(BuildContext context, Map<String, dynamic> row) {
    final amount = row['amount'] as num?;
    final date = DateTime.tryParse('${row['createdAt']}')
        ?.toUtc()
        .add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onOpen(row),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transactionTitle(row),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    if (date != null)
                      Text(
                        '${two(date.day)}/${two(date.month)}/${date.year} • ${two(date.hour)}:${two(date.minute)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      amount == null
                          ? '—'
                          : '${amount > 0
                                ? '+'
                                : amount < 0
                                ? '−'
                                : ''}${_money(amount.abs())}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: amount != null && amount > 0
                            ? const Color(0xFF168A45)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
