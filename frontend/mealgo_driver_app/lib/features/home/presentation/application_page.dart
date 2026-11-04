import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../api_client.dart';
import '../../../driver_store.dart';
import 'widgets/onboarding_components.dart';

class ApplicationPage extends StatefulWidget {
  const ApplicationPage({super.key, required this.store});
  final DriverStore store;
  @override
  State<ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<ApplicationPage> {
  static const orange = Color(0xFFF24B30);
  static const ink = Color(0xFF242421);
  static const muted = Color(0xFF85837E);
  static const canvas = OnboardingStyle.background;
  final formKey = GlobalKey<FormState>();
  final dateKey = GlobalKey<FormFieldState<String>>();
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
    'Ngày sinh',
    'Địa chỉ liên hệ',
    'Số CCCD',
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
  DateTime? birthDate;

  String formatBirthDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString().padLeft(4, '0')}';

  Future<void> pickBirthDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day - 1);
    final firstDate = DateTime(1);
    final initialDate =
        birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : initialDate.isAfter(lastDate)
          ? lastDate
          : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (selected == null || !mounted) return;
    setState(() {
      birthDate = selected;
      fields[1].text = formatBirthDate(selected);
    });
    dateKey.currentState?.didChange(fields[1].text);
  }

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
      final message = e is ApiException
          ? switch (e.status) {
              0 => 'Không thể kết nối. Bạn kiểm tra mạng rồi thử lại nhé.',
              401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
              403 => 'Tài khoản chưa có quyền thực hiện thao tác này.',
              409 => 'Hồ sơ đã thay đổi. Hãy tải lại để kiểm tra trạng thái mới nhất.',
              413 => 'Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn 5 MB.',
              503 => 'Chưa thể lưu giấy tờ lúc này. Vui lòng thử lại sau.',
              _ => 'Chưa thể xử lý hồ sơ. Kiểm tra thông tin và thử lại nhé.',
            }
          : 'Thao tác chưa hoàn tất. Vui lòng thử lại.';
      if (mounted) setState(() => error = message);
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
      birthDate = DateTime.tryParse(data!['birthDate']?.toString() ?? '');
      fields[1].text = birthDate == null ? '' : formatBirthDate(birthDate!);
    });
    if (data!['status'] == 'APPROVED') await widget.store.refresh();
  });
  Future<void> save() async {
    final result = await widget.store.api.request(
      'PUT',
      '/drivers/me/application',
      {
        for (var i = 0; i < keys.length; i++) keys[i]: fields[i].text.trim(),
        'birthDate':
            '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
      },
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
    if (bytes.length > 5 * 1024 * 1024) throw ApiException(413, '');
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
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: orange,
          surface: canvas,
        ),
        textTheme: theme.textTheme.apply(bodyColor: ink, displayColor: ink),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0EFEB),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          hintStyle: const TextStyle(color: muted, fontSize: 14),
          border: fieldBorder(Colors.transparent),
          enabledBorder: fieldBorder(Colors.transparent),
          disabledBorder: fieldBorder(Colors.transparent),
          focusedBorder: fieldBorder(orange),
          errorBorder: fieldBorder(const Color(0xFFDBABA5)),
          focusedErrorBorder: fieldBorder(const Color(0xFFBC4B41)),
          errorStyle: const TextStyle(color: Color(0xFFBC4B41), fontSize: 12),
          errorMaxLines: 2,
        ),
      ),
      child: Scaffold(
        backgroundColor: canvas,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'MealGo Driver',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!pending)
                          Text(
                            '${step + 1} / 3',
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        IconButton(
                          onPressed: busy ? null : widget.store.logout,
                          tooltip: 'Đăng xuất',
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!pending)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: List.generate(
                          3,
                          (index) => Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: EdgeInsets.only(
                                right: index == 2 ? 0 : 6,
                              ),
                              height: 4,
                              decoration: BoxDecoration(
                                color: index <= step
                                    ? orange
                                    : const Color(0xFFE5E3DE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Form(
                      key: formKey,
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                        children: [
                          if (pending)
                            ...pendingContent()
                          else ...[
                            Text(
                              'BƯỚC ${step + 1} · ${['THÔNG TIN CÁ NHÂN', 'PHƯƠNG TIỆN & GIẤY TỜ', 'KIỂM TRA HỒ SƠ'][step]}',
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: orange,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OnboardingHeader(
                              title: [
                                'Bắt đầu với\nthông tin của bạn',
                                'Sẵn sàng cho\nhành trình mới',
                                'Một bước nữa,\ncùng MealGo!',
                              ][step],
                              subtitle: [
                                'Điền thông tin cá nhân để tạo hồ sơ đăng ký trở thành đối tác tài xế MealGo.',
                                'Thêm thông tin xe và giấy tờ để chúng tôi xác minh hồ sơ của bạn.',
                                'Kiểm tra thông tin trước khi gửi. Hồ sơ sẽ được khóa để xét duyệt.',
                              ][step],
                            ),
                            const SizedBox(height: 26),
                            if (data != null && step < 2)
                              for (
                                var i = step == 0 ? 0 : 4;
                                i < (step == 0 ? 4 : 7);
                                i++
                              )
                                input(i),
                            if (data != null && step == 0)
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: muted,
                                    size: 16,
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'Thông tin của bạn chỉ được dùng để xác minh hồ sơ đối tác.',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (data != null && step == 1) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Giấy tờ xác minh',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Ảnh rõ nét, PNG hoặc JPEG · Tối đa 5 MB/ảnh',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              for (final entry in documents.entries)
                                documentTile(entry),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        if (formKey.currentState!.validate()) {
                                          run(save);
                                        }
                                      },
                                child: const Text('Lưu nháp và tiếp tục sau'),
                              ),
                            ],
                            if (data != null && step == 2)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: List.generate(
                                    keys.length,
                                    (i) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              labels[i],
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              fields[i].text,
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: LinearProgressIndicator(
                                color: orange,
                                minHeight: 2,
                              ),
                            ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAEDEA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    error!,
                                    style: const TextStyle(
                                      color: Color(0xFFAA463B),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  footer(pending),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );

  Widget input(int index) {
    const hints = [
      'Nguyễn Văn An',
      'Chọn ngày sinh',
      'Số nhà, đường, phường/xã',
      'Nhập 12 chữ số CCCD',
      'Ví dụ: Xe máy',
      'Ví dụ: 59A1-12345',
      'Nhập số giấy phép lái xe',
    ];
    const limits = [150, 0, 500, 12, 50, 20, 30];
    return AppTextField(
      key: ValueKey(keys[index]),
      fieldKey: index == 1 ? dateKey : null,
      label: index == 1 ? 'Ngày sinh' : labels[index],
      hint: hints[index],
      controller: fields[index],
      enabled: !busy,
      readOnly: index == 1,
      onTap: index == 1
          ? () {
              FocusScope.of(context).unfocus();
              pickBirthDate();
            }
          : null,
      keyboardType: index == 3
          ? TextInputType.number
          : index == 2
          ? TextInputType.streetAddress
          : TextInputType.text,
      textCapitalization: index == 0 || index == 2
          ? TextCapitalization.words
          : TextCapitalization.none,
      textInputAction: index == 3 || index == 6
          ? TextInputAction.done
          : TextInputAction.next,
      autofillHints: index == 0
          ? const [AutofillHints.name]
          : index == 2
          ? const [AutofillHints.fullStreetAddress]
          : null,
      inputFormatters: index == 3
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ]
          : null,
      prefixIcon: index == 1
          ? const Icon(Icons.calendar_today_outlined, size: 19, color: muted)
          : null,
      suffixIcon: index == 1
          ? const Icon(Icons.keyboard_arrow_down_rounded, color: muted)
          : null,
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) {
          return index == 1
              ? 'Vui lòng chọn ngày sinh.'
              : 'Vui lòng nhập ${labels[index].toLowerCase()}.';
        }
        if (index == 1) {
          final now = DateTime.now();
          if (birthDate == null ||
              !birthDate!.isBefore(DateTime(now.year, now.month, now.day))) {
            return 'Ngày sinh phải là ngày trong quá khứ.';
          }
        } else if (index == 3 && !RegExp(r'^[0-9]{12}$').hasMatch(text)) {
          return 'Số CCCD cần đúng 12 chữ số.';
        } else if (text.length > limits[index]) {
          return 'Vui lòng nhập tối đa ${limits[index]} ký tự.';
        }
        return null;
      },
    );
  }

  Widget documentTile(MapEntry<String, String> entry) {
    final uploaded = (data?['documents'] as List? ?? []).contains(entry.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          onTap: busy ? null : () => upload(entry.key),
          leading: Icon(
            uploaded
                ? Icons.check_circle_rounded
                : Icons.add_photo_alternate_outlined,
            color: uploaded ? const Color(0xFF4E8263) : orange,
          ),
          title: Text(
            entry.value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            uploaded ? 'Đã tải lên · Chạm để thay ảnh' : 'Chạm để chọn ảnh',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: muted),
        ),
      ),
    );
  }

  List<Widget> pendingContent() => [
    const SizedBox(height: 32),
    const Icon(Icons.task_alt_rounded, color: orange, size: 64),
    const SizedBox(height: 24),
    const Text(
      'Đã nhận hồ sơ\ncủa bạn',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 14),
    const Text(
      'MealGo đang kiểm tra thông tin và giấy tờ. Bạn có thể bắt đầu nhận chuyến sau khi hồ sơ được phê duyệt.',
      textAlign: TextAlign.center,
      style: TextStyle(color: muted, height: 1.6),
    ),
    const SizedBox(height: 24),
    SelectableText(
      'Mã hồ sơ\n${data!['applicationId']}',
      textAlign: TextAlign.center,
      style: const TextStyle(color: muted, fontSize: 12, height: 1.8),
    ),
  ];

  Widget footer(bool pending) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    decoration: const BoxDecoration(
      color: canvas,
      border: Border(top: BorderSide(color: Color(0xFFEDEBE6))),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!pending && step > 0)
          TextButton(
            onPressed: busy
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      step--;
                      error = null;
                    });
                  },
            child: const Text('Quay lại'),
          ),
        AppPrimaryButton(
          loading: busy,
          onPressed: busy
              ? null
              : pending || data == null
              ? load
              : continueFlow,
          label: pending
              ? 'Kiểm tra trạng thái'
              : data == null
              ? 'Tải lại hồ sơ'
              : step == 2
              ? 'Xác nhận và gửi hồ sơ'
              : 'Tiếp tục',
        ),
        if (!pending && data != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              [
                'Bước tiếp theo: Phương tiện và giấy tờ',
                'Bước tiếp theo: Kiểm tra hồ sơ',
                'Thông tin sẽ được gửi để xét duyệt',
              ][step],
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
      ],
    ),
  );

  void continueFlow() {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (step == 0) {
      setState(() {
        step = 1;
        error = null;
      });
      return;
    }
    if (step == 1 && (data?['documents'] as List? ?? []).length < 4) {
      setState(
        () => error = 'Vui lòng tải đủ 4 ảnh giấy tờ trước khi tiếp tục.',
      );
      return;
    }
    run(() async {
      await save();
      if (!mounted) return;
      if (step == 1) {
        setState(() => step = 2);
      } else {
        final result = await widget.store.api.request(
          'POST',
          '/drivers/me/application/submit',
        );
        if (mounted) setState(() => data = Map<String, dynamic>.from(result));
      }
    });
  }
}
