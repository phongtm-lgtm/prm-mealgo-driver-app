import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class OnboardingStyle {
  static const background = Color(0xFFF8F9FB);
  static const orange = Color(0xFFF24B30);
  static const ink = Color(0xFF242421);
  static const muted = Color(0xFF797D86);
  static OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: OnboardingStyle.ink,
          fontSize: 30,
          height: 1.2,
          letterSpacing: -0.8,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: const TextStyle(
          color: OnboardingStyle.muted,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    ],
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.fieldKey,
    this.enabled = true,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
  });
  final String label;
  final String? hint, helper;
  final TextEditingController controller;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final FormFieldValidator<String>? validator;
  final bool enabled, obscureText, readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon, suffixIcon;
  final TextCapitalization textCapitalization;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF565C66),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          autocorrect: false,
          enableSuggestions: false,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          scrollPadding: const EdgeInsets.all(28),
          validator: validator,
          style: const TextStyle(
            color: OnboardingStyle.ink,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF0F1F4),
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            errorMaxLines: 2,
            hintStyle: const TextStyle(color: Color(0xFF969AA2), fontSize: 14),
            helperStyle: const TextStyle(
              color: OnboardingStyle.muted,
              fontSize: 12,
            ),
            errorStyle: const TextStyle(color: Color(0xFFB64E47), fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OnboardingStyle.border(Colors.transparent),
            enabledBorder: OnboardingStyle.border(Colors.transparent),
            disabledBorder: OnboardingStyle.border(Colors.transparent),
            focusedBorder: OnboardingStyle.border(OnboardingStyle.orange),
            errorBorder: OnboardingStyle.border(const Color(0xFFE4BBB7)),
            focusedErrorBorder: OnboardingStyle.border(const Color(0xFFB64E47)),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    ),
  );
}

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.helper,
    this.validator,
    this.fieldKey,
    this.onChanged,
    this.enabled = true,
    this.last = false,
  });
  final String label;
  final String? helper;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final ValueChanged<String>? onChanged;
  final bool enabled, last;
  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => AppTextField(
    label: widget.label,
    hint: widget.last ? 'Nhập lại mật khẩu' : 'Tạo mật khẩu của bạn',
    controller: widget.controller,
    helper: widget.helper,
    validator: widget.validator,
    fieldKey: widget.fieldKey,
    onChanged: widget.onChanged,
    enabled: widget.enabled,
    obscureText: hidden,
    keyboardType: TextInputType.visiblePassword,
    autofillHints: const [AutofillHints.newPassword],
    textInputAction: widget.last ? TextInputAction.done : TextInputAction.next,
    suffixIcon: IconButton(
      tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: widget.enabled ? () => setState(() => hidden = !hidden) : null,
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: OnboardingStyle.muted,
        size: 21,
      ),
    ),
  );
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: OnboardingStyle.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE7DCD8),
        disabledForegroundColor: const Color(0xFF77716F),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: OnboardingStyle.muted,
                ),
              ),
            ),
          Flexible(
            child: Text(
              loading ? 'Đang xử lý…' : label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (!loading)
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(Icons.arrow_forward_rounded, size: 18),
            ),
        ],
      ),
    ),
  );
}

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 48,
              child: Checkbox(
                value: value,
                onChanged: onChanged == null ? null : (v) => onChanged!(v!),
                activeColor: OnboardingStyle.orange,
                side: const BorderSide(color: Color(0xFFB7BBC3), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}
