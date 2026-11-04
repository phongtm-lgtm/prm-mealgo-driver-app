import 'package:flutter/material.dart';

import '../../../driver_store.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.store});
  final DriverStore store;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneNumber = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() {
    phoneNumber.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 400,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.delivery_dining, size: 64),
                  const Text(
                    'MealGo Driver',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: phoneNumber,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      hintText: '0900000001',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  ),
                  const SizedBox(height: 16),
                  if (widget.store.error != null)
                    Text(
                      widget.store.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  FilledButton(
                    onPressed: widget.store.busy
                        ? null
                        : () => widget.store.login(
                            phoneNumber.text.trim(),
                            password.text,
                          ),
                    child: Text(
                      widget.store.busy ? 'Đang đăng nhập…' : 'Đăng nhập',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.store.busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RegistrationPage(store: widget.store),
                            ),
                          ),
                    child: const Text('Đăng ký làm đối tác tài xế'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
