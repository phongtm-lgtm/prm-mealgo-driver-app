import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';
import '../domain/driver.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final DriverController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late DriverSettings _draft = widget.controller.settings;
  bool _saving = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cài đặt ứng dụng')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DemoNotice(
          text: 'Cài đặt được lưu trên máy chủ. Khoảng cách tính đường chim bay từ quán đến khách.',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Nhận đơn tự động',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tự động nhận đơn'),
                subtitle: const Text(
                  'Chỉ lưu tùy chọn; hiện vẫn cần xác nhận nhận đơn thủ công.',
                ),
                value: _draft.autoAccept,
                onChanged: _saving
                    ? null
                    : (v) => setState(
                        () => _draft = _draft.copyWith(autoAccept: v),
                      ),
              ),
              const Text(
                'Trạng thái và thời hạn đề nghị do máy chủ quyết định.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Khoảng cách giao hàng',
          child: Column(
            children: [
              Text('Tối đa ${_draft.maxDistance.toStringAsFixed(1)} km'),
              Slider(
                value: _draft.maxDistance,
                min: 0.1,
                max: 100,
                divisions: 999,
                label: '${_draft.maxDistance.round()} km',
                onChanged: _saving
                    ? null
                    : (v) => setState(
                        () => _draft = _draft.copyWith(maxDistance: v),
                      ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Giới hạn nhận đơn',
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: _draft.maxItems,
                decoration: const InputDecoration(
                  labelText: 'Số lượng món tối đa',
                ),
                items:
                    ({1, 3, 5, 10, 20, 50, 100, 5000, _draft.maxItems}.toList()
                          ..sort())
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text('$v món')),
                        )
                        .toList(),
                onChanged: _saving
                    ? null
                    : (v) =>
                          setState(() => _draft = _draft.copyWith(maxItems: v)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _draft.maxAdvance,
                decoration: const InputDecoration(
                  labelText: 'Tiền trả quán tối đa',
                ),
                items:
                    ({0, 100000, 200000, 500000, _draft.maxAdvance}.toList()
                          ..sort())
                        .map(
                          (v) =>
                              DropdownMenuItem(value: v, child: Text(money(v))),
                        )
                        .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(
                        () => _draft = _draft.copyWith(maxAdvance: v),
                      ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Máy chủ lọc tổng số phần ăn và khoảng cách. Luồng COD hiện không cần ứng tiền quán (0đ).',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        SectionCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thông báo trong ứng dụng'),
            value: _draft.notifications,
            onChanged: _saving
                ? null
                : (v) => setState(
                    () => _draft = _draft.copyWith(notifications: v),
                  ),
          ),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final ok = await widget.controller.saveSettings(_draft);
                  if (!context.mounted) return;
                  setState(() => _saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Đã lưu cài đặt lên máy chủ'
                            : (widget.controller.error ??
                                  'Không thể lưu. Vui lòng thử lại. Có thể một phần cài đặt đã được lưu.'),
                      ),
                    ),
                  );
                },
          child: Text(_saving ? 'Đang lưu…' : 'Lưu cài đặt'),
        ),
      ],
    ),
  );
}
