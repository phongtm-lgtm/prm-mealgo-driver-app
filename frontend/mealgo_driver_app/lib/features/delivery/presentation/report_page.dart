import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../driver_store.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';
import '../domain/delivery.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.controller, required this.order});
  final DriverController controller;
  final DeliveryOrder order;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _note = TextEditingController();
  bool _eligible = false;
  bool _evidence = false;
  List<int>? _bytes;
  String _filename = 'evidence.jpg';
  String _requestId = DriverStore.uuid();
  bool _submitting = false;
  String _reason = 'Không liên lạc được với khách';
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Báo cáo giao thất bại')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DemoNotice(
          text: 'Báo cáo được gửi lên máy chủ với ảnh bằng chứng thật.',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Điều kiện gửi báo cáo',
          child: Column(
            children: [
              const Text(
                'Cần xác minh thời gian chờ và lịch sử liên hệ trước khi gửi. Quy tắc thật sẽ do backend kiểm tra.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tôi đã liên hệ và chờ khách tại điểm giao'),
                value: _eligible,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _eligible = v!),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Thông tin báo cáo • ${widget.order.id}',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                items:
                    [
                          'Không liên lạc được với khách',
                          'Khách từ chối nhận hàng',
                          'Địa chỉ không chính xác',
                        ]
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: _submitting
                    ? null
                    : (s) => setState(() {
                        _reason = s!;
                        _requestId = DriverStore.uuid();
                      }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                maxLength: 1000,
                onChanged: (_) => _requestId = DriverStore.uuid(),
                enabled: !_submitting,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mô tả sự việc',
                  hintText: 'Nhập chi tiết để bộ phận hỗ trợ kiểm tra',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () async {
                        try {
                          final photo = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                            maxWidth: 2000,
                          );
                          if (photo == null) return;
                          final bytes = await photo.readAsBytes();
                          if (!mounted) return;
                          if (bytes.length > 5 * 1024 * 1024) {
                            setState(() => _error = 'Ảnh tối đa 5 MB.');
                            return;
                          }
                          setState(() {
                            _bytes = bytes;
                            _filename = photo.name;
                            _evidence = true;
                            _requestId = DriverStore.uuid();
                          });
                        } catch (_) {
                          if (mounted)
                            setState(() => _error = 'Không chọn được ảnh.');
                        }
                      },
                icon: Icon(
                  _evidence ? Icons.check_circle : Icons.add_a_photo_outlined,
                ),
                label: Text(
                  _evidence
                      ? 'Đã chọn ảnh bằng chứng'
                      : 'Đính kèm ảnh bằng chứng',
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Đang gửi…' : 'Gửi báo cáo'),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!_eligible || !_evidence || _note.text.trim().isEmpty) {
      setState(
        () => _error = 'Vui lòng xác nhận điều kiện, nhập mô tả và chọn ảnh.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final success = await widget.controller.reportFailure(
      DeliveryReport(
        orderId: widget.order.id,
        reason: _reason,
        note: _note.text.trim(),
        evidence: _filename,
        bytes: _bytes,
        requestId: _requestId,
      ),
    );
    if (!mounted) return;
    if (success) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã gửi báo cáo'),
          content: const Text(
            'Máy chủ đã ghi nhận giao thất bại và lưu ảnh bằng chứng. Chưa có khoản bồi thường được ghi nhận.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _submitting = false;
        _error = widget.controller.error;
      });
    }
  }
}
