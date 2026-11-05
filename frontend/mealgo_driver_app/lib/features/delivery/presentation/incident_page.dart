import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../driver_store.dart';
import '../../home/presentation/driver_controller.dart';
import '../domain/delivery.dart';

class IncidentPage extends StatefulWidget {
  const IncidentPage({
    super.key,
    required this.controller,
    required this.order,
    required this.reason,
    required this.reasonLabel,
  });
  final DriverController controller;
  final DeliveryOrder order;
  final String reason;
  final String reasonLabel;
  @override
  State<IncidentPage> createState() => _IncidentPageState();
}

class _IncidentPageState extends State<IncidentPage> {
  final _note = TextEditingController();
  String _requestId = DriverStore.uuid();
  Uint8List? _bytes;
  String _filename = 'evidence.jpg';
  String? _error;
  bool _sending = false;
  bool get _closed => widget.reason == 'RESTAURANT_CLOSED';
  bool get _requiresPhoto => _closed || widget.reason == 'CUSTOMER_UNREACHABLE';
  String get _photoLabel => _closed ? 'ảnh quán đóng cửa' : 'ảnh chụp lịch sử cuộc gọi nhỡ';
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _photo(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024)
        throw StateError('Ảnh phải từ 1 byte đến 5 MB.');
      setState(() {
        _bytes = bytes;
        _filename = image.name;
        _requestId = DriverStore.uuid();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_closed ? 'Quán đóng cửa' : 'Yêu cầu chuyển đơn'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _closed
                ? 'Đính kèm ảnh quán đóng cửa và cập nhật GPS tại quán để chuyển chuyến cho tài xế khác.'
                : 'Khi xác nhận, đơn hàng sẽ được phân phối cho tài xế khác.',
          ),
          const SizedBox(height: 16),
          Text(widget.reasonLabel),
          TextField(
            controller: _note,
            enabled: !_sending,
            maxLength: 1000,
            maxLines: 4,
            onChanged: (_) => _requestId = DriverStore.uuid(),
            decoration: const InputDecoration(labelText: 'Mô tả sự việc'),
          ),
          if (_requiresPhoto) ...[
            if (_bytes != null)
              Image.memory(_bytes!, height: 200, fit: BoxFit.contain),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _sending ? null : () => _photo(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Chụp ảnh'),
                ),
                OutlinedButton.icon(
                  onPressed: _sending
                      ? null
                      : () => _photo(ImageSource.gallery),
                  icon: const Icon(Icons.image),
                  label: const Text('Chọn ảnh'),
                ),
              ],
            ),
            Text(
              _bytes == null
                  ? 'Thêm $_photoLabel (PNG hoặc JPEG, tối đa 5 MB).'
                  : 'Đã đính kèm bằng chứng. Có thể chọn ảnh khác.',
            ),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: Text(
              _sending
                  ? 'Đang gửi…'
                  : _requiresPhoto
                  ? 'Gửi ảnh và bỏ chuyến'
                  : 'Xác nhận chuyển đơn',
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (_requiresPhoto && _bytes == null) {
      setState(() => _error = 'Vui lòng đính kèm $_photoLabel.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    // GPS refresh can fail without discarding the evidence or idempotency key.
    if (_closed) await widget.controller.updateLocation();
    final ok = await widget.controller.submitIncident(
      widget.order.id,
      widget.reason,
      _note.text.trim(),
      _requestId,
      _bytes,
      _filename,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = ok ? null : widget.controller.error;
    });
    if (!ok) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đã bỏ chuyến'),
        content: const Text('Đơn hàng sẽ được phân phối cho tài xế khác'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
    if (mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
  }
}
