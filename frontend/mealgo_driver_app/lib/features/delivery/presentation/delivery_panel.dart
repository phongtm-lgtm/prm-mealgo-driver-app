import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/delivery_distance.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';
import '../domain/delivery.dart';
import 'report_page.dart';
import 'incident_page.dart';

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
                Expanded(
                  child: ListenableBuilder(
                    listenable: controller.backend?.store ?? controller,
                    builder: (context, _) {
                      final routeMeters =
                          controller.backend?.store.routeDistanceMeters;
                      final String distanceText;
                      final String subText;

                      if (preview) {
                        distanceText = formatDeliveryDistance(
                          order.distance,
                          available: order.hasDistance,
                        );
                        subText = 'Quán ➔ Khách';
                      } else {
                        if (order.stage.index <
                            DeliveryStage.pickedUp.index) {
                          distanceText = routeMeters != null
                              ? (routeMeters < 1000
                                  ? '${routeMeters.round()} m'
                                  : '${(routeMeters / 1000).toStringAsFixed(2)} km')
                              : formatDeliveryDistance(
                                  order.distance,
                                  available: order.hasDistance,
                                );
                          subText = 'Đến quán lấy hàng';
                        } else {
                          distanceText = routeMeters != null
                              ? (routeMeters < 1000
                                  ? '${routeMeters.round()} m'
                                  : '${(routeMeters / 1000).toStringAsFixed(2)} km')
                              : formatDeliveryDistance(
                                  order.distance,
                                  available: order.hasDistance,
                                );
                          subText = 'Đến điểm giao khách';
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            distanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${money(order.fee > 0 ? order.fee : (order.distance * 10000).round())}',
                      style: const TextStyle(
                        color: Color(0xFFA3E97C),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '10.000 đ/km',
                      style: TextStyle(
                        color: Color(0xFFA3E97C),
                        fontSize: 11,
                      ),
                    ),
                  ],
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
              title: 'Chi tiết đơn hàng • ${order.orderId ?? order.id}',
              child: Column(
                children: [
                  InfoRow('Món ăn', order.item),
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
                      'Thu tiền mặt từ khách. Khoản này không phải tiền công của bạn.',
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
          ] else
            InfoRow('Tiền cần thu từ khách', money(order.total)),
          const SizedBox(height: 12),
        ],
        if (actionOnly && !order.stage.isTerminal)
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: controller.busy ? null : () => _chooseReason(context, release: false),
                icon: const Icon(Icons.report_problem_outlined, size: 18),
                label: const Text('Báo cáo đơn hàng'),
              ),
              if (order.canRelease)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: controller.busy ? null : () => _chooseReason(context, release: true),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Hủy chuyến'),
                ),
            ],
          ),
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

  Future<void> _chooseReason(BuildContext context, {required bool release}) async {
    const releaseReasons = {
      'VEHICLE_BREAKDOWN': 'Xe hỏng',
      'BAD_WEATHER': 'Thời tiết xấu',
      'PERSONAL': 'Sự cố cá nhân',
    };
    const restaurantReasons = {
      'RESTAURANT_CLOSED': 'Quán đóng cửa',
      'RESTAURANT_DELAY': 'Quán chuẩn bị quá lâu',
    };
    const deliveryReasons = {
      'CUSTOMER_UNREACHABLE': 'Khách không nghe máy',
      'WRONG_ADDRESS': 'Sai thông tin giao hàng',
      'CUSTOMER_REFUSED': 'Khách từ chối nhận hàng',
    };
    final reasons = release ? releaseReasons : {
      if (order.canRelease) ...restaurantReasons,
      ...deliveryReasons,
    };
    bool requiresDropoff(String key, DeliveryOrder trip) =>
        deliveryReasons.containsKey(key) &&
        !(key == 'CUSTOMER_UNREACHABLE' && trip.canRelease);
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                release ? 'Chọn lý do hủy chuyến' : 'Báo cáo đơn hàng',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final entry in reasons.entries)
              ListTile(
                title: Text(entry.value),
                subtitle: requiresDropoff(entry.key, order) &&
                        order.stage != DeliveryStage.atCustomer
                    ? const Text('Gửi sau khi xác nhận đã đến điểm giao')
                    : null,
                trailing: const Icon(Icons.chevron_right),
                enabled: !requiresDropoff(entry.key, order) || order.stage == DeliveryStage.atCustomer,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted || controller.activeOrder?.id != order.id) return;
    final current = controller.activeOrder!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => requiresDropoff(reason, current)
            ? ReportPage(controller: controller, order: current, initialReason: reason)
            : IncidentPage(controller: controller, order: current, reason: reason,
                reasonLabel: reasons[reason]!),
      ),
    );
  }
}
