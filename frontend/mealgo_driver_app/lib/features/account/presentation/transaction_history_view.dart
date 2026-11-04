import 'package:flutter/material.dart';

import '../../../core/formatters.dart';

String transactionTitle(Map<String, dynamic> row) => switch (row['type']) {
  'DELIVERY_EARNING' => 'Thu nhập giao hàng',
  _ => 'Giao dịch ví',
};

String shortTransactionId(dynamic value) {
  final id = '$value';
  return id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
}

class TransactionHistoryView extends StatefulWidget {
  const TransactionHistoryView({
    super.key,
    required this.rows,
    required this.loading,
    required this.failed,
    required this.hasNext,
    required this.onMore,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> rows;
  final bool loading, failed, hasNext;
  final VoidCallback onMore;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  State<TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<TransactionHistoryView> {
  int _period = 0;
  DateTime? _date(Map<String, dynamic> row) =>
      DateTime.tryParse('${row['createdAt']}')
          ?.toUtc()
          .add(const Duration(hours: 7));
  String _day(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _amount(num value) =>
      '${value > 0
          ? '+'
          : value < 0
          ? '−'
          : ''}${money(value.abs().round())}';
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = _period == 1
        ? today
        : today.subtract(Duration(days: now.weekday - 1));
    final rows =
        widget.rows.where((row) {
          if (_period == 0) return true;
          final date = _date(row);
          if (date == null) return false;
          final day = DateTime.utc(date.year, date.month, date.day);
          return !day.isBefore(start) &&
              day.isBefore(today.add(const Duration(days: 1)));
        }).toList()..sort(
          (a, b) => (_date(b) ?? DateTime.utc(1970)).compareTo(
            _date(a) ?? DateTime.utc(1970),
          ),
        );
    final complete =
        !widget.hasNext &&
        !widget.loading &&
        !widget.failed &&
        widget.rows.every((r) => r['amount'] is num && _date(r) != null);
    final incoming = rows.fold<num>(
      0,
      (sum, row) =>
          sum + ((row['amount'] as num? ?? 0) > 0 ? row['amount'] as num : 0),
    );
    final outgoing = rows.fold<num>(
      0,
      (sum, row) =>
          sum +
          ((row['amount'] as num? ?? 0) < 0 ? (row['amount'] as num).abs() : 0),
    );
    String? previousDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['Tất cả', 'Hôm nay', 'Tuần này'][i]),
                selected: _period == i,
                showCheckmark: false,
                onSelected: (_) => setState(() => _period = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: .15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Biến động số dư trong kỳ'),
              const SizedBox(height: 8),
              Text(
                complete ? _amount(incoming - outgoing) : '—',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final items = [
                    _summary(
                      'Tiền vào',
                      complete ? _amount(incoming) : '—',
                      const Color(0xFF168650),
                    ),
                    _summary(
                      'Tiền ra',
                      complete ? _amount(-outgoing) : '—',
                      theme.colorScheme.onSurface,
                    ),
                  ];
                  return constraints.maxWidth < 280
                      ? Wrap(spacing: 24, runSpacing: 12, children: items)
                      : Row(
                          children: [
                            for (final item in items) Expanded(child: item),
                          ],
                        );
                },
              ),
              const SizedBox(height: 12),
              Text(
                complete
                    ? 'Đây là thay đổi trong kỳ, không phải số dư khả dụng.'
                    : 'Tải hết giao dịch để xem tổng tiền trong thời gian đã chọn.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Giao dịch gần đây',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.hasNext && _period != 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Đang hiển thị kết quả trong các giao dịch đã tải.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        if (!widget.loading && !widget.failed && rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _period == 0 && !widget.hasNext
                      ? 'Bạn chưa có giao dịch nào.'
                      : 'Không tìm thấy giao dịch phù hợp.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final row in rows) ...[
          if (previousDay !=
              (_date(row) == null ? 'Chưa có thời gian' : _day(_date(row)!)))
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                previousDay = _date(row) == null
                    ? 'Chưa có thời gian'
                    : _day(_date(row)!),
                style: theme.textTheme.labelLarge,
              ),
            ),
          _tile(context, row),
        ],
        if (widget.hasNext)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              onPressed: widget.loading ? null : widget.onMore,
              child: Text(widget.loading ? 'Đang tải…' : 'Tải thêm giao dịch'),
            ),
          ),
      ],
    );
  }

  Widget _summary(String title, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    ],
  );

  Widget _tile(BuildContext context, Map<String, dynamic> row) {
    final theme = Theme.of(context);
    final date = _date(row);
    final amount = row['amount'] as num?;
    final time = date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpen(row),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  row['type'] == 'DELIVERY_EARNING'
                      ? Icons.delivery_dining_outlined
                      : Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
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
                    Text(
                      [
                        if (row['deliveryId'] != null)
                          'Chuyến #${shortTransactionId(row['deliveryId'])}',
                        if (time.isNotEmpty) time,
                      ].join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      amount == null ? 'Chưa có số tiền' : _amount(amount),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: amount != null && amount > 0
                            ? const Color(0xFF168650)
                            : theme.colorScheme.onSurface,
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
