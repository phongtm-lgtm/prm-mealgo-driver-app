import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../api_client.dart';
import '../../../driver_store.dart';

class ApplicationPage extends StatefulWidget {
  const ApplicationPage({super.key, required this.store});
  final DriverStore store;
  @override
  State<ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<ApplicationPage> {
  final keys = [
    'fullName',
    'birthDate',
    'address',
    'identityNumber',
    'vehicleType',
    'licensePlate',
    'drivingLicense',
  ];
  final labels = [
    'Họ và tên',
    'Ngày sinh (YYYY-MM-DD)',
    'Địa chỉ liên hệ',
    'Số CCCD (12 số)',
    'Loại xe',
    'Biển số xe',
    'Số giấy phép lái xe',
  ];
  final fields = List.generate(7, (_) => TextEditingController());
  final documents = const {
    'IDENTITY_FRONT': 'CCCD mặt trước',
    'IDENTITY_BACK': 'CCCD mặt sau',
    'VEHICLE_REGISTRATION': 'Đăng ký xe',
    'DRIVING_LICENSE': 'Giấy phép lái xe',
  };
  Map<String, dynamic>? data;
  bool busy = false;
  String? error;
  int step = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    final result = await widget.store.api.request(
      'GET',
      '/drivers/me/application',
    );
    if (!mounted) return;
    setState(() {
      data = Map<String, dynamic>.from(result);
      for (var i = 0; i < keys.length; i++) {
        fields[i].text = data![keys[i]]?.toString() ?? '';
      }
    });
    if (data!['status'] == 'APPROVED') await widget.store.refresh();
  });
  Future<void> save() async {
    if (fields.any((c) => c.text.trim().isEmpty))
      throw Exception('Vui lòng nhập đầy đủ thông tin.');
    if (DateTime.tryParse(fields[1].text) == null)
      throw Exception('Ngày sinh phải có dạng YYYY-MM-DD.');
    final result = await widget.store.api.request(
      'PUT',
      '/drivers/me/application',
      {for (var i = 0; i < keys.length; i++) keys[i]: fields[i].text.trim()},
    );
    if (mounted) setState(() => data = Map<String, dynamic>.from(result));
  }

  Future<void> upload(String type) => run(() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) throw Exception('Ảnh tối đa 5 MB.');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiClient.baseUrl}/api/v1/drivers/me/application/documents/$type',
      ),
    );
    request.headers['Authorization'] = 'Bearer ${widget.store.api.token}';
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: image.name),
    );
    final response = await widget.store.api.client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final result = widget.store.api.decode(
      await http.Response.fromStream(response),
    );
    if (mounted) setState(() => data = Map<String, dynamic>.from(result));
  });
  @override
  void dispose() {
    for (final c in fields) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = data?['status'] == 'PENDING_REVIEW';
    return Scaffold(
      appBar: AppBar(
        title: Text(pending ? 'Trạng thái hồ sơ' : 'Đăng ký đối tác tài xế'),
        actions: [
          IconButton(
            onPressed: busy ? null : widget.store.logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: busy ? null : load,
                  child: const Text('Tải lại'),
                ),
              ],
              if (data == null && !busy)
                FilledButton(onPressed: load, child: const Text('Tải hồ sơ')),
              if (pending) ...[
                const Icon(Icons.hourglass_top, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Hồ sơ đang chờ quản trị viên duyệt',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Bạn chỉ có thể bắt đầu ca và nhận đơn sau khi hồ sơ được duyệt.',
                ),
                const SizedBox(height: 16),
                SelectableText('Mã hồ sơ: ${data!['applicationId']}'),
                FilledButton.icon(
                  onPressed: busy ? null : load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Kiểm tra trạng thái'),
                ),
              ] else if (data != null) ...[
                Text(
                  'Bước ${step + 1}/3 • ${['Thông tin cá nhân', 'Phương tiện và giấy tờ', 'Kiểm tra và gửi hồ sơ'][step]}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (step < 2)
                  for (var i = step == 0 ? 0 : 4; i < (step == 0 ? 4 : 7); i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: fields[i],
                        enabled: !busy,
                        decoration: InputDecoration(labelText: labels[i]),
                      ),
                    ),
                if (step == 1)
                  for (final e in documents.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.value),
                      subtitle: Text(
                        (data!['documents'] as List).contains(e.key)
                            ? 'Đã tải lên'
                            : 'Chưa có ảnh',
                      ),
                      trailing: IconButton(
                        onPressed: busy ? null : () => upload(e.key),
                        icon: const Icon(Icons.upload),
                      ),
                    ),
                if (step == 2) ...[
                  for (var i = 0; i < keys.length; i++)
                    ListTile(
                      title: Text(labels[i]),
                      subtitle: Text(fields[i].text),
                    ),
                  const Text(
                    'Khi gửi, bạn xác nhận thông tin và giấy tờ là chính xác. Hồ sơ sẽ được khóa để xét duyệt.',
                  ),
                ],
                if (step > 0)
                  TextButton(
                    onPressed: busy ? null : () => setState(() => step--),
                    child: const Text('Quay lại'),
                  ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          if (step == 0) {
                            if (fields
                                .take(4)
                                .any((c) => c.text.trim().isEmpty))
                              throw Exception(
                                'Vui lòng nhập đủ thông tin cá nhân.',
                              );
                            setState(() => step++);
                          } else if (step == 1) {
                            await save();
                            if ((data!['documents'] as List).length < 4)
                              throw Exception('Vui lòng tải đủ 4 ảnh giấy tờ.');
                            setState(() => step++);
                          } else {
                            await save();
                            final result = await widget.store.api.request(
                              'POST',
                              '/drivers/me/application/submit',
                            );
                            if (mounted)
                              setState(
                                () => data = Map<String, dynamic>.from(result),
                              );
                          }
                        }),
                  child: Text(step == 2 ? 'Xác nhận và gửi hồ sơ' : 'Tiếp tục'),
                ),
                if (step == 1)
                  TextButton(
                    onPressed: busy ? null : () => run(save),
                    child: const Text('Lưu nháp'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
