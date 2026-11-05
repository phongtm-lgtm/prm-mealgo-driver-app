import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../driver_store.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../../home/presentation/driver_controller.dart';
import '../domain/delivery.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.controller, required this.order,
      this.initialReason = 'CUSTOMER_UNREACHABLE'});
  final DriverController controller;
  final DeliveryOrder order;
  final String initialReason;

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
  late String _reason = widget.initialReason;
  static const reasons = {
    'CUSTOMER_UNREACHABLE': 'Khách không nghe máy',
    'CUSTOMER_REFUSED': 'Khách từ chối nhận hàng',
    'WRONG_ADDRESS': 'Sai thông tin giao hàng',
  };
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: Scaffold(
      appBar: AppBar(title: const Text('Báo cáo giao thất bại')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.order.stage != DeliveryStage.atCustomer)
            const SectionCard(
              title: 'Chưa đủ điều kiện báo cáo',
              child: Text(
                'Hãy đến địa chỉ khách và xác nhận “Đã đến điểm giao” trước khi báo giao không thành công.',
              ),
            ),
          const DemoNotice(
            text: 'Chọn lý do và đính kèm ảnh để được hỗ trợ khi không thể giao hàng.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Điều kiện gửi báo cáo',
            child: Column(
              children: [
                const Text(
                  'Máy chủ yêu cầu chuyến ở trạng thái đã đến điểm giao. Xác nhận liên hệ dưới đây là khai báo của tài xế; chưa có quy tắc tự kiểm tra thời gian chờ.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tôi đã liên hệ và chờ khách tại điểm giao',
                  ),
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
                  items: reasons.entries
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.key,
                              child: Text(
                                s.value,
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
                if (_bytes != null)
                  Image.memory(
                    Uint8List.fromList(_bytes!),
                    height: 200,
                    fit: BoxFit.contain,
                  ),
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
                      : _reason == 'CUSTOMER_UNREACHABLE'
                      ? 'Đính kèm ảnh chụp lịch sử cuộc gọi'
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
            onPressed:
                _submitting || widget.order.stage != DeliveryStage.atCustomer
                ? null
                : _submit,
            child: Text(_submitting ? 'Đang gửi…' : 'Gửi báo cáo'),
          ),
        ],
      ),
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
    if (success && ModalRoute.of(context)?.isCurrent == true) {
      setState(() => _submitting = false);
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
      if (mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
    } else {
      setState(() {
        _submitting = false;
        _error = widget.controller.error;
      });
    }
  }
}
