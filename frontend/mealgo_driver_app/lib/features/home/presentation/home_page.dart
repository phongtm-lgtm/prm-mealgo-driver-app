import 'package:flutter/material.dart';

import '../../../core/delivery_distance.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/server_error_view.dart';
import '../../account/presentation/account_page.dart';
import '../../delivery/presentation/delivery_panel.dart';
import '../../delivery/presentation/delivery_map.dart';
import '../../driver/presentation/settings_page.dart';
import 'driver_controller.dart';
import 'face_verification_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, this.onLogout});
  final Future<void> Function()? onLogout;
  final DriverController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.serverUnavailable) {
        return ServerErrorView(
          loading: controller.busy,
          onRetry: () => controller.initialize(),
        );
      }
      if (!controller.initialized) {
        return Scaffold(
          body: Center(
            child: controller.error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(controller.error!),
                      FilledButton(
                        onPressed: controller.initialize,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delivery_dining, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.profile!.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'MealGo Driver • Free Pick Hub',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: StatusPill(
                controller.online ? '● ONLINE' : '● OFFLINE',
                color: controller.online ? AppColors.green : Colors.grey,
              ),
            ),
            IconButton(
              tooltip: 'Thông báo',
              onPressed: () =>
                  _openAccount(context, AccountSection.notifications),
              icon: const Icon(Icons.notifications_none),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Row(
              children: [
                _tab('FREE-PICK', false),
                _tab(
                  'ĐANG LÀM${controller.activeOrder != null ? ' • 1' : ''}',
                  true,
                ),
              ],
            ),
          ),
        ),
        drawer: _drawer(context),
        bottomNavigationBar:
            controller.showingActive && controller.activeOrder != null
            ? Material(
                color: AppColors.background,
                elevation: 8,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: DeliveryPanel(
                    controller: controller,
                    order: controller.activeOrder!,
                    actionOnly: true,
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            if (controller.busy) const LinearProgressIndicator(minHeight: 2),
            if (controller.error != null)
              MaterialBanner(
                content: Text(
                  controller.error!,
                  style: const TextStyle(fontSize: 12),
                ),
                actions: [
                  TextButton(
                    onPressed: controller.clearError,
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final displayedOrder = controller.showingActive
                      ? controller.activeOrder
                      : (controller.selectedOrder ??
                          controller.offer ??
                          controller.activeOrder);

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                        height: (constraints.maxHeight * .46).clamp(
                          200.0,
                          430.0,
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child:
                                  displayedOrder != null &&
                                      controller.backend != null
                                  ? DeliveryMap(
                                      order: displayedOrder,
                                      store: controller.backend!.store,
                                    )
                                  : const ColoredBox(
                                      color: Color(0xFFEEF4F6),
                                      child: Center(
                                        child: Text(
                                          'Bản đồ chuyến hiện tại sẽ hiển thị tại đây',
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Column(
                                children: [
                                  FloatingActionButton.small(
                                    heroTag: 'refresh',
                                    tooltip: 'Làm mới đơn',
                                    backgroundColor: Colors.white,
                                    onPressed: controller.busy
                                        ? null
                                        : controller.refresh,
                                    child: const Icon(Icons.refresh),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
                                    heroTag: 'location',
                                    tooltip: 'Cập nhật GPS',
                                    backgroundColor: Colors.white,
                                    onPressed: controller.backend != null
                                        ? controller.updateLocation
                                        : null,
                                    child: const Icon(Icons.my_location),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight:
                              (constraints.maxHeight -
                                      (constraints.maxHeight * .46).clamp(
                                        200.0,
                                        430.0,
                                      ))
                                  .clamp(0.0, double.infinity),
                        ),
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [

                            if (controller.offer != null) ...[
                              SectionCard(
                                title:
                                    'Đề nghị mới • ${controller.offerSeconds}s',
                                child: Column(
                                  children: [
                                    Text(
                                      controller.offer!.restaurant,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    InfoRow(
                                      '${controller.offer!.distance} km',
                                      '+${money(controller.offer!.fee)}',
                                      color: AppColors.green,
                                    ),
                                    SlideAction(
                                      label:
                                          'Trượt để nhận • ${controller.offerSeconds}s',
                                      enabled: !controller.busy,
                                      onSubmit: () =>
                                          controller.accept(controller.offer!),
                                    ),
                                    TextButton(
                                      onPressed: () => controller.rejectOffer(),
                                      child: const Text('Từ chối đề nghị'),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (controller.showingActive &&
                                controller.activeOrder != null)
                              DeliveryPanel(
                                controller: controller,
                                order: controller.activeOrder!,
                                showAction: false,
                              )
                            else if (controller.showingActive)
                              const SectionCard(
                                title: 'Chưa có đơn đang giao',
                                child: Text(
                                  'Chuyển sang FREE-PICK để chọn đơn khi đang trong ca.',
                                ),
                              )
                            else if (controller.selectedOrder != null &&
                                controller.online)
                              DeliveryPanel(
                                controller: controller,
                                order: controller.selectedOrder!,
                                preview: true,
                              )
                            else ...[
                              SectionCard(
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFFEEF4FF),
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Hôm nay',
                                            style: TextStyle(
                                              color: AppColors.muted,
                                            ),
                                          ),
                                          Text(
                                            '${controller.completedToday} đơn hoàn thành',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      money(controller.earnedToday),
                                      style: const TextStyle(
                                        color: AppColors.green,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (controller.online) ...[
                                Row(
                                  children: [
                                    Text(
                                      '${controller.available.length} đơn khả dụng',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    const StatusPill(
                                      'FREE-PICK',
                                      color: AppColors.teal,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (controller.available.isEmpty)
                                  const SectionCard(
                                    child: Text(
                                      'Không có đơn phù hợp. Thử tăng khoảng cách trong cài đặt.',
                                    ),
                                  ),
                                for (final order in controller.available)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFE2F5F0),
                                          child: Icon(
                                            Icons.storefront,
                                            color: AppColors.teal,
                                          ),
                                        ),
                                        title: Text(
                                          order.restaurant,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${formatDeliveryDistance(order.distance, available: order.hasDistance)} • đường chim bay',
                                        ),
                                        trailing: Text(
                                          '+${money(order.fee)}',
                                          style: const TextStyle(
                                            color: AppColors.green,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        onTap: () =>
                                            controller.selectOrder(order),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _tab(String text, bool active) => Expanded(
    child: InkWell(
      onTap: () => controller.showActive(active),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 3,
              color: controller.showingActive == active
                  ? AppColors.primary
                  : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: controller.showingActive == active
                ? Colors.white
                : Colors.grey,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );

  Widget _drawer(BuildContext context) => Drawer(
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person_outline, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.profile!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.profile!.rating > 0
                                ? '☆ ${controller.profile!.rating} / 5'
                                : '☆ Chưa có đánh giá',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tài xế MealGo',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          _menuLabel('Tài khoản'),
          for (final entry in <AccountSection, IconData>{
            AccountSection.profile: Icons.person_outline,
            AccountSection.notifications: Icons.notifications_none,
          }.entries)
            _accountMenuItem(context, entry.key, entry.value),
          _menuDivider(),
          _menuLabel('Thu nhập & giao dịch'),
          for (final entry in <AccountSection, IconData>{
            AccountSection.earnings: Icons.bar_chart,
            AccountSection.wallet: Icons.account_balance_wallet_outlined,
            AccountSection.transactions: Icons.receipt_long,
          }.entries)
            _accountMenuItem(context, entry.key, entry.value),
          _menuDivider(),
          _menuLabel('Hoạt động'),
          _accountMenuItem(context, AccountSection.orders, Icons.history),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Cài đặt ứng dụng'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(controller: controller),
                ),
              );
            },
          ),
          _menuDivider(),
          ListTile(
            leading: Icon(controller.online ? Icons.logout : Icons.login),
            title: Text(controller.online ? 'Kết thúc ca' : 'Bắt đầu ca'),
            enabled: !controller.busy,
            onTap: () {
              Navigator.pop(context);
              _shift(context, !controller.online);
            },
          ),
          if (onLogout != null) ...[
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Đăng xuất',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Đăng xuất tài khoản?'),
                    content: const Text(
                      'Bạn cần đăng nhập lại để tiếp tục sử dụng ứng dụng. Đăng xuất không kết thúc ca hoặc bỏ chuyến đang giao.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Ở lại'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await onLogout!();
              },
            ),
          ],
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'MealGo Driver v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _menuLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _menuDivider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Divider(),
  );

  Widget _accountMenuItem(
    BuildContext context,
    AccountSection section,
    IconData icon,
  ) => ListTile(
    leading: Icon(icon, size: 21),
    title: Text(
      section == AccountSection.orders ? 'Lịch sử giao hàng' : section.title,
      style: const TextStyle(fontSize: 14),
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: () {
      Navigator.pop(context);
      _openAccount(context, section);
    },
  );

  void _openAccount(BuildContext context, AccountSection section) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AccountPage(controller: controller, section: section),
        ),
      );

  Future<void> _shift(BuildContext context, bool online) async {
    if (controller.backend == null) return;
    if (online && controller.backend != null) {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FaceVerificationPage(
            verify: controller.backend!.store.api.verifyFace,
          ),
        ),
      );
      if (verified != true || !context.mounted) return;
      final success = await controller.setOnline(true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Đã vào ca'
                  : controller.error ?? 'Không thể vào ca. Vui lòng thử lại.',
            ),
          ),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          online ? Icons.face : Icons.logout,
          size: 48,
          color: AppColors.primary,
        ),
        title: Text(online ? 'Bắt đầu ca làm việc' : 'Kết thúc ca làm việc?'),
        content: Text('Bạn muốn ngừng nhận đơn và kết thúc ca làm việc?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận ra ca'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await controller.setOnline(online);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(online ? 'Đã vào ca' : 'Đã kết thúc ca')),
        );
      }
    }
  }
}
