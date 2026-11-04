import 'package:flutter/material.dart';

/// History summaries intentionally describe loaded rows, not the whole account.
class OrderHistoryView extends StatefulWidget {
  const OrderHistoryView({
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
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  int _period = 0;
  DateTime? _date(Map<String, dynamic> row) => DateTime.tryParse(
    '${row['deliveredAt'] ?? row['failedAt'] ?? row['updatedAt']}',
  )?.toUtc().add(const Duration(hours: 7));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = _period == 1
        ? today
        : today.subtract(Duration(days: now.weekday - 1));
    final rows = widget.rows.where((row) {
      if (_period == 0) return true;
      final date = _date(row);
      if (date == null) return false;
      final day = DateTime.utc(date.year, date.month, date.day);
      return !day.isBefore(start) &&
          day.isBefore(today.add(const Duration(days: 1)));
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['Tất cả', 'Hôm nay', 'Tuần này'][i]),
                selected: _period == i,
                showCheckmark: false,
                selectedColor: primary,
                labelStyle: TextStyle(
                  color: _period == i ? Colors.white : null,
                ),
                onSelected: (_) => setState(() => _period = i),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: .15),
            ),
          ),
          child: Row(
            children: [
              _stat(
                context,
                Icons.receipt_long_outlined,
                'Đơn hàng',
                '${rows.length}',
              ),
              _stat(
                context,
                Icons.check_circle_outline,
                'Đã giao',
                '${rows.where((r) => r['status'] == 'DELIVERED').length}',
              ),
              _stat(context, Icons.payments_outlined, 'Tiền công', '—'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Thống kê trên các đơn đã tải. Xem tiền công trong giao dịch ví.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Các chuyến giao',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text('${rows.length} đơn', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty && !widget.loading && !widget.failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.hasNext
                      ? 'Chưa tìm thấy đơn trong các đơn đã tải.'
                      : 'Chưa có đơn hàng trong thời gian này.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn thời gian khác hoặc tải lại để kiểm tra.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final row in rows) _card(context, row),
        if (widget.hasNext)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: widget.loading ? null : widget.onMore,
              child: Text(widget.loading ? 'Đang tải…' : 'Tải thêm đơn hàng'),
            ),
          ),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );

  Widget _card(BuildContext context, Map<String, dynamic> row) {
    final theme = Theme.of(context);
    final status = switch (row['status']) {
      'DELIVERED' => ('Đã giao', const Color(0xFF168650)),
      'FAILED' => ('Giao không thành công', const Color(0xFFB65B15)),
      'CANCELLED' => ('Đã hủy', const Color(0xFFB33A42)),
      _ => ('Chuyến giao', theme.colorScheme.onSurfaceVariant),
    };
    final id = '${row['deliveryId'] ?? ''}';
    final date = _date(row);
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: .15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onOpen(row),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Mã chuyến: ${id.length > 8 ? id.substring(0, 8).toUpperCase() : id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: status.$2.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.$1,
                        style: TextStyle(
                          color: status.$2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  date == null
                      ? 'Chưa có thời gian cập nhật'
                      : '${two(date.hour)}:${two(date.minute)} • ${two(date.day)}/${two(date.month)}/${date.year}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                _stop(
                  context,
                  Icons.storefront_outlined,
                  '${row['restaurant']?['name'] ?? 'Điểm lấy hàng'}',
                  '${row['pickup']?['address'] ?? 'Chưa có địa chỉ'}',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    height: 16,
                    width: 1,
                    color: theme.dividerColor,
                  ),
                ),
                _stop(
                  context,
                  Icons.location_on_outlined,
                  'Giao đến',
                  '${row['dropoff']?['address'] ?? 'Chưa có địa chỉ'}',
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: .2),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Xem chi tiết chuyến',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stop(
    BuildContext context,
    IconData icon,
    String title,
    String address,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(address, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}
