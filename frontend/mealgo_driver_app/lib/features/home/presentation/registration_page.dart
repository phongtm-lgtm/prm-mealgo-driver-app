import 'dart:async';

import 'package:flutter/material.dart';

import '../../../driver_store.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.store});
  final DriverStore store;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final form = GlobalKey<FormState>();
  final phone = TextEditingController(), password = TextEditingController();
  final confirm = TextEditingController(), otp = TextEditingController();
  Map<String, dynamic>? challenge;
  bool busy = false, agreed = false, hidden = true;
  String? error;
  Timer? timer;
  int get remaining => challenge == null
      ? 0
      : DateTime.parse(challenge!['resendAt'])
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 60);
  Future<void> run(Future<void> Function() action) async {
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

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [phone, password, confirm, otp]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(challenge == null ? 'Đăng ký tài khoản' : 'Xác minh OTP'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (challenge == null) ...[
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  validator: (v) =>
                      RegExp(r'^(?:0|\+84)[35789][0-9]{8}$').hasMatch(v!.trim())
                      ? null
                      : 'Số điện thoại không hợp lệ',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: hidden,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: const Icon(Icons.visibility),
                    ),
                  ),
                  validator: (v) => v!.length >= 8 && v.length <= 72
                      ? null
                      : 'Mật khẩu từ 8–72 ký tự',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Xác nhận mật khẩu',
                  ),
                  validator: (v) =>
                      v == password.text ? null : 'Mật khẩu không khớp',
                ),
                CheckboxListTile(
                  value: agreed,
                  onChanged: busy ? null : (v) => setState(() => agreed = v!),
                  title: const Text(
                    'Tôi đồng ý cung cấp thông tin để đăng ký đối tác tài xế.',
                  ),
                ),
              ] else ...[
                Text('Xác minh số điện thoại ${phone.text}'),
                const SizedBox(height: 16),
                Text(
                  'Chế độ phát triển — không gửi SMS thật.\nOTP phát triển: ${challenge!['devOtp']}',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Mã OTP'),
                  validator: (v) =>
                      RegExp(r'^\d{6}$').hasMatch(v!) ? null : 'Nhập mã 6 số',
                ),
                TextButton(
                  onPressed: busy || remaining > 0
                      ? null
                      : () => run(() async {
                          final data = await widget.store.api.request(
                            'POST',
                            '/auth/register/resend',
                            {'registrationId': challenge!['registrationId']},
                          );
                          setState(() {
                            challenge = Map<String, dynamic>.from(data);
                            otp.clear();
                          });
                        }),
                  child: Text(
                    remaining > 0 ? 'Gửi lại sau ${remaining}s' : 'Gửi lại mã',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          challenge = null;
                          otp.clear();
                        }),
                  child: const Text('Đổi số điện thoại / Đăng ký lại'),
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        if (!form.currentState!.validate()) return;
                        if (challenge == null && !agreed) {
                          setState(() => error = 'Vui lòng xác nhận đồng ý.');
                          return;
                        }
                        run(() async {
                          if (challenge == null) {
                            final data = await widget.store.api.request(
                              'POST',
                              '/auth/register/start',
                              {
                                'phoneNumber': phone.text.trim(),
                                'password': password.text,
                              },
                            );
                            setState(
                              () => challenge = Map<String, dynamic>.from(data),
                            );
                            timer ??= Timer.periodic(
                              const Duration(seconds: 1),
                              (_) {
                                if (mounted) setState(() {});
                              },
                            );
                          } else {
                            await widget.store.api.request(
                              'POST',
                              '/auth/register/verify',
                              {
                                'registrationId': challenge!['registrationId'],
                                'otp': otp.text,
                              },
                            );
                            await widget.store.login(
                              phone.text.trim(),
                              password.text,
                            );
                            if (mounted && widget.store.authenticated)
                              Navigator.of(context).pop();
                          }
                        });
                      },
                child: Text(
                  busy
                      ? 'Đang xử lý…'
                      : challenge == null
                      ? 'Tiếp tục'
                      : 'Xác minh',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
