import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/delivery_distance.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';
import '../domain/delivery.dart';
import 'report_page.dart';

class DeliveryPanel extends StatelessWidget {
  const DeliveryPanel({
    super.key,
    required this.controller,
    required this.order,
    this.preview = false,
    this.showAction = true,
    this.actionOnly = false,
  });
  final DriverController controller;
  final DeliveryOrder order;
  final bool preview;
  final bool showAction;
  final bool actionOnly;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!actionOnly) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  controller.backend != null
                      ? '${formatDeliveryDistance(order.distance, available: order.hasDistance)}${order.hasDistance ? '\nĐường chim bay' : ''}'
                      : '${order.distance} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  controller.backend != null
                      ? 'Phí: chưa có dữ liệu'
                      : '+${money(order.fee)}',
                  style: const TextStyle(
                    color: Color(0xFFA3E97C),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront, color: AppColors.primary),
            title: Text(
              order.restaurant,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(order.pickupAddress),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.location_on_outlined,
              color: AppColors.teal,
            ),
            title: Text(order.customer),
            subtitle: Text(order.dropoffAddress),
          ),
          if (!preview) ...[
            StatusPill(order.stage.label, color: AppColors.primary),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Chi tiết đơn hàng • ${order.id}',
              child: Column(
                children: [
                  InfoRow(order.item, '1 × ${money(order.total)}'),
                  const Divider(),
                  InfoRow('Tổng tiền trả quán', '0 đ', bold: true),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '✓ Không cần trả tiền cho quán',
                      style: TextStyle(color: AppColors.green),
                    ),
                  ),
                  InfoRow(
                    'Tổng tiền thu khách',
                    money(order.total),
                    color: AppColors.primary,
                    bold: true,
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Thu tiền mặt • Không đưa hóa đơn cho khách',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _contact(context, 'Cuộc gọi'),
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Gọi điện'),
                ),
                TextButton.icon(
                  onPressed: () => _contact(context, 'Tin nhắn'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Nhắn tin'),
                ),
              ],
            ),
            if (order.stage.index <= DeliveryStage.atPickup.index)
              TextButton.icon(
                onPressed: controller.busy ? null : () => _reject(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Từ chối / Quán đóng cửa'),
              ),
            if (order.stage == DeliveryStage.atCustomer)
              TextButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ReportPage(controller: controller, order: order),
                        ),
                      ),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Báo cáo giao thất bại'),
              ),
          ] else
            InfoRow('Thu khách • 1 món', money(order.total)),
          const SizedBox(height: 12),
        ],
        if (showAction)
          SlideAction(
            label: preview ? 'Trượt để nhận đơn' : order.stage.action,
            enabled: !controller.busy,
            onSubmit: () async {
              if (preview) {
                await controller.accept(order);
              } else {
                final completing = order.stage == DeliveryStage.atCustomer;
                if (completing) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Xác nhận hoàn thành'),
                      content: Text(
                        'Bạn đã giao món và thu ${money(order.total)} từ khách?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Chưa'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Đã thu tiền'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                }
                final success = await controller.advance();
                if (success && completing && context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      icon: const Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                        size: 60,
                      ),
                      title: const Text('Giao hàng thành công!'),
                      content: const Text(
                        'Máy chủ đã xác nhận giao thành công.',
                        textAlign: TextAlign.center,
                      ),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tiếp tục nhận đơn'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
          ),
        if (preview && !actionOnly)
          TextButton(
            onPressed: () => controller.selectOrder(null),
            child: const Text('Chọn đơn khác'),
          ),
      ],
    ),
  );

  void _contact(BuildContext context, String action) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(action),
      content: const Text(
        'Chưa kết nối dịch vụ gọi điện / chat. Không có liên hệ thật được thực hiện.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  Future<void> _reject(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Chọn lý do từ chối',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final reason in [
              'Lý do cá nhân',
              'Quán chuẩn bị quá lâu',
              'Quán đã đóng cửa',
            ])
              ListTile(
                title: Text(reason),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    if (reason == 'Quán đã đóng cửa') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bằng chứng quán đóng cửa'),
          content: const Text(
            'Chưa hỗ trợ gửi bằng chứng quán đóng cửa tại bước này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      return;
    }
    await controller.rejectActive(reason);
  }
}
