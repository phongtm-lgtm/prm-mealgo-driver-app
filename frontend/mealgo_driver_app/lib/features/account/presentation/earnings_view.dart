import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';

class EarningsView extends StatelessWidget {
  const EarningsView({
    super.key,
    required this.data,
    required this.onTransactions,
  });
  final Map<String, dynamic> data;
  final VoidCallback onTransactions;
  String _money(num value) =>
      money(value.round()).replaceAll(RegExp(r'\s'), '');
  String _date(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data['totalEarnings'] as num;
    final count = data['completedDeliveries'] as num;
    final chart = (data['chart'] as List? ?? []).cast<Map>();
    final maxValue = chart.fold<double>(
      0,
      (value, row) => math.max(value, (row['earnings'] as num).toDouble()),
    );
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tổng thu nhập • ${_date(data['fromDate'])}${data['fromDate'] == data['toDate'] ? '' : ' – ${_date(data['toDate'])}'}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Text(
            _money(total),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
            _stat(context, 'Đơn đã ghi nhận tiền công', '$count đơn'),
              _stat(
                context,
                'Trung bình mỗi đơn',
                count > 0 ? _money(total / count) : '—',
              ),
            ],
          ),
          if (data['earningsConfigured'] != true) ...[
            const SizedBox(height: 16),
            const Text('Chưa có mức tiền công cho chuyến giao mới.'),
          ],
          const SizedBox(height: 28),
          Text(
            'Biểu đồ thu nhập',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text('Theo ngày • Giờ Việt Nam', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          if (chart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Chưa có thu nhập trong thời gian này.',
                textAlign: TextAlign.center,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  constraints.maxWidth,
                  chart.length * 56.0,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 180,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    4,
                                    (_) => Divider(
                                      height: 1,
                                      color: theme.dividerColor.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final row in chart)
                                    Expanded(
                                      child: Tooltip(
                                        triggerMode: TooltipTriggerMode.tap,
                                        message:
                                            '${_date(row['date'])}: ${_money(row['earnings'] as num)}',
                                        child: Semantics(
                                          label:
                                              '${_date(row['date'])}: ${_money(row['earnings'] as num)}',
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              width: 32,
                                              height: maxValue <= 0
                                                  ? 2
                                                  : 2 +
                                                        166 *
                                                            ((row['earnings']
                                                                        as num) /
                                                                    maxValue)
                                                                .clamp(0, 1),
                                              decoration: BoxDecoration(
                                                color:
                                                    (row['earnings'] as num) ==
                                                            maxValue &&
                                                        maxValue > 0
                                                    ? primary
                                                    : primary.withValues(
                                                        alpha: .35,
                                                      ),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(9),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final row in chart)
                              Expanded(
                                child: Text(
                                  _date(row['date'])
                                      .replaceFirst(RegExp(r'/\d{4}$'), ''),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Text(
            'Chi tiết thu nhập',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.delivery_dining_outlined, size: 20, color: primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Tiền công giao hàng')),
              const SizedBox(width: 8),
              Text(
                _money(total),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Expanded(child: Text('Tổng thu nhập')),
              Text(
                _money(total),
                style: TextStyle(color: primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Không bao gồm tiền thu hộ từ khách. Thu nhập không phải số dư có thể rút.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onTransactions,
            child: const Text('Xem lịch sử giao dịch'),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
    ],
  );
}
