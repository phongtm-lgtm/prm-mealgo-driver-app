import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api_client.dart';
import '../../../driver_store.dart';
import 'widgets/onboarding_components.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.store});
  final DriverStore store;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final form = GlobalKey<FormState>();
  final confirmKey = GlobalKey<FormFieldState<String>>();
  final phone = TextEditingController(), password = TextEditingController();
  final confirm = TextEditingController(), otp = TextEditingController();
  final scroll = ScrollController();
  Map<String, dynamic>? challenge;
  bool busy = false, agreed = false;
  String? error;
  Timer? timer;

  int get remaining => challenge == null
      ? 0
      : DateTime.parse(challenge!['resendAt'])
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 60);

  Future<void> run(
    Future<void> Function() action, {
    bool resending = false,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final verifying = challenge != null;
      final message = e is ApiException
          ? switch (e.status) {
              0 => 'Không thể kết nối. Kiểm tra mạng rồi thử lại nhé.',
              409 when resending =>
                'Chưa thể gửi lại mã. Vui lòng chờ một chút rồi thử lại.',
              409 when verifying => 'Chưa thể xác minh lúc này. Hãy gửi lại mã hoặc đăng ký lại để tiếp tục.',
              409 => 'Chưa thể đăng ký số điện thoại này. Nếu bạn đã có tài khoản, hãy quay lại đăng nhập; nếu vừa yêu cầu mã, hãy chờ 60 giây rồi thử lại.',
              400 when verifying => 'Mã xác minh chưa đúng hoặc phiên đã hết hạn. Kiểm tra mã, hoặc đăng ký lại để nhận phiên mới.',
              400 => 'Chưa thể bắt đầu đăng ký. Kiểm tra thông tin; nếu vẫn không được, hãy thử lại sau.',
              _ => 'Đăng ký chưa hoàn tất. Vui lòng thử lại sau ít phút.',
            }
          : 'Thao tác chưa hoàn tất. Vui lòng thử lại.';
      setState(() => error = message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void submit() {
    if (busy || !form.currentState!.validate()) return;
    if (challenge == null && !agreed) return;
    FocusScope.of(context).unfocus();
    run(() async {
      if (challenge == null) {
        final data = await widget.store.api.request(
          'POST',
          '/auth/register/start',
          {'phoneNumber': phone.text.trim(), 'password': password.text},
        );
        if (!mounted) return;
        setState(() => challenge = Map<String, dynamic>.from(data));
        scroll.jumpTo(0);
        timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      } else {
        await widget.store.api.request('POST', '/auth/register/verify', {
          'registrationId': challenge!['registrationId'],
          'otp': otp.text,
        });
        await widget.store.login(phone.text.trim(), password.text);
        if (mounted && widget.store.authenticated) Navigator.of(context).pop();
      }
    });
  }

  void showPolicy(String title) {
    // No published legal copy or URL exists in this project. Do not fabricate it.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OnboardingStyle.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nội dung chính thức hiện chưa được cung cấp trong ứng dụng. Vui lòng liên hệ MealGo để được hỗ trợ trước khi đồng ý.',
                style: TextStyle(color: OnboardingStyle.muted, height: 1.6),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Đóng',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    scroll.dispose();
    for (final c in [phone, password, confirm, otp]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: OnboardingStyle.orange,
        surface: OnboardingStyle.background,
      ),
    ),
    child: Scaffold(
      backgroundColor: OnboardingStyle.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.maybePop(context),
                        tooltip: 'Quay lại',
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: OnboardingStyle.ink,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.delivery_dining_rounded,
                        color: OnboardingStyle.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'MealGo Driver',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: OnboardingStyle.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: form,
                    child: ListView(
                      controller: scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      children: [
                        OnboardingHeader(
                          title: challenge == null
                              ? 'Tạo tài khoản\ntài xế'
                              : 'Xác minh\nsố điện thoại',
                          subtitle: challenge == null
                              ? 'Thiết lập thông tin đăng nhập để bắt đầu hành trình cùng MealGo.'
                              : 'Xác minh số điện thoại ${phone.text.trim()} để tiếp tục đăng ký đối tác.',
                        ),
                        const SizedBox(height: 28),
                        if (challenge == null) ...[
                          AppTextField(
                            key: const ValueKey('registration-phone'),
                            label: 'Số điện thoại',
                            hint: 'Ví dụ: 0901234567',
                            controller: phone,
                            enabled: !busy,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational,
                            ],
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Vui lòng nhập số điện thoại.'
                                : RegExp(r'^(?:0|\+84)[35789][0-9]{8}$')
                                      .hasMatch(v!.trim())
                                ? null
                                : 'Nhập số di động Việt Nam bắt đầu bằng 03, 05, 07, 08, 09 hoặc +84 tương ứng.',
                          ),
                          AppPasswordField(
                            label: 'Mật khẩu',
                            controller: password,
                            enabled: !busy,
                            helper:
                                'Sử dụng từ 8–72 ký tự cho mật khẩu của bạn.',
                            onChanged: (_) {
                              if (confirm.text.isNotEmpty) {
                                confirmKey.currentState?.validate();
                              }
                            },
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Vui lòng nhập mật khẩu.'
                                : v!.length >= 8 && v.length <= 72
                                ? null
                                : 'Mật khẩu cần từ 8 đến 72 ký tự.',
                          ),
                          AppPasswordField(
                            label: 'Xác nhận mật khẩu',
                            controller: confirm,
                            enabled: !busy,
                            fieldKey: confirmKey,
                            last: true,
                            validator: (v) => (v ?? '').isEmpty
                                ? 'Vui lòng nhập lại mật khẩu.'
                                : v == password.text
                                ? null
                                : 'Mật khẩu xác nhận không khớp.',
                          ),
                          AppCheckbox(
                            value: agreed,
                            onChanged: busy
                                ? null
                                : (value) => setState(() => agreed = value),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: OnboardingStyle.muted,
                                    height: 1.7,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Tôi đã đọc và đồng ý với ',
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: policyLink('Điều khoản sử dụng'),
                                    ),
                                    const TextSpan(text: ' và '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: policyLink('Chính sách bảo mật'),
                                    ),
                                    const TextSpan(text: ' của MealGo.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEE8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Chế độ phát triển — không gửi SMS thật.\nOTP phát triển: ${challenge!['devOtp']}',
                              style: const TextStyle(
                                color: Color(0xFF974B38),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          AppTextField(
                            key: const ValueKey('registration-otp'),
                            label: 'Mã OTP',
                            hint: 'Nhập mã 5 chữ số',
                            controller: otp,
                            enabled: !busy,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            validator: (v) =>
                                RegExp(r'^[0-9]{5}$').hasMatch(v ?? '')
                                ? null
                                : 'Vui lòng nhập mã OTP gồm 5 chữ số.',
                          ),
                          TextButton(
                            onPressed: busy || remaining > 0
                                ? null
                                : () => run(() async {
                                    final data = await widget.store.api.request(
                                      'POST',
                                      '/auth/register/resend',
                                      {
                                        'registrationId':
                                            challenge!['registrationId'],
                                      },
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      challenge = Map<String, dynamic>.from(
                                        data,
                                      );
                                      otp.clear();
                                    });
                                    form.currentState?.reset();
                                  }, resending: true),
                            child: Text(
                              remaining > 0
                                  ? 'Gửi lại mã sau ${remaining}s'
                                  : 'Gửi lại mã',
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    challenge = null;
                                    otp.clear();
                                    error = null;
                                  }),
                            child: const Text(
                              'Đổi số điện thoại / Đăng ký lại',
                            ),
                          ),
                        ],
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
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
                                    fontSize: 13,
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
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: const BoxDecoration(
                    color: OnboardingStyle.background,
                    border: Border(top: BorderSide(color: Color(0xFFECEEF2))),
                  ),
                  child: AppPrimaryButton(
                    label: challenge == null ? 'Tiếp tục' : 'Xác minh',
                    loading: busy,
                    onPressed: challenge == null && !agreed ? null : submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget policyLink(String label) => InkWell(
    onTap: busy ? null : () => showPolicy(label),
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        label,
        style: const TextStyle(
          color: OnboardingStyle.orange,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: OnboardingStyle.orange,
        ),
      ),
    ),
  );
}
