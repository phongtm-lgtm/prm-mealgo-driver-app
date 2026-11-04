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
  String get _distance =>
      _draft.maxDistance.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cài đặt ứng dụng')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Khoảng cách nhận đơn',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chỉ nhận đơn trong phạm vi bạn chọn.'),
              const SizedBox(height: 12),
              Text('Tối đa $_distance km'),
              Slider(
                value: _draft.maxDistance,
                min: 0.1,
                max: 100,
                divisions: 999,
                label: '$_distance km',
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
          title: 'Đơn hàng bạn muốn nhận',
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _draft.maxItems,
                decoration: const InputDecoration(
                  labelText: 'Số món tối đa trong một đơn',
                  helperText: 'Chọn số món nhiều nhất bạn có thể giao.',
                  helperMaxLines: 2,
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
                isExpanded: true,
                initialValue: _draft.maxAdvance,
                decoration: const InputDecoration(
                  labelText: 'Số tiền cần ứng tối đa',
                  helperText: 'Số tiền bạn sẵn sàng trả trước khi lấy hàng.',
                  helperMaxLines: 2,
                ),
                items:
                    ({0, 100000, 200000, 500000, _draft.maxAdvance}.toList()
                          ..sort())
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              v == 0 ? '0 đ — Không ứng tiền' : money(v),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(
                        () => _draft = _draft.copyWith(maxAdvance: v),
                      ),
              ),
            ],
          ),
        ),
        SectionCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nhận thông báo'),
            subtitle: const Text(
              'Cập nhật đơn mới và những thông tin quan trọng.',
            ),
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
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  final ok = await widget.controller.saveSettings(_draft);
                  if (!context.mounted) return;
                  setState(() => _saving = false);
                  final message = ok
                      ? 'Đã lưu thay đổi của bạn.'
                      : widget.controller.lastRequestConnectionFailed
                      ? 'Không có kết nối mạng. Hãy kiểm tra và thử lại.'
                      : 'Chưa thể lưu thay đổi. Vui lòng thử lại.';
                  widget.controller.clearError();
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message)));
                },
          child: Text(_saving ? 'Đang lưu…' : 'Lưu cài đặt'),
        ),
      ],
    ),
  );
}
