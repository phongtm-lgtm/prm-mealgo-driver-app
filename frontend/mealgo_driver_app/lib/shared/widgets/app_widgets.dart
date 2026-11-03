import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(
    this.label,
    this.value, {
    super.key,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color ?? AppColors.ink,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = AppColors.green});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({
    super.key,
    this.text = 'Tính năng này hiện chưa được hỗ trợ.',
  });
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    color: const Color(0xFFFFF1DA),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, color: Color(0xFF865400)),
    ),
  );
}

class SlideAction extends StatefulWidget {
  const SlideAction({
    super.key,
    required this.label,
    required this.onSubmit,
    this.enabled = true,
    this.color = AppColors.primary,
  });
  final String label;
  final VoidCallback onSubmit;
  final bool enabled;
  final Color color;

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> {
  double _position = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final travel = (constraints.maxWidth - 62).clamp(1.0, double.infinity);
      return Semantics(
        button: true,
        label: widget.label,
        enabled: widget.enabled,
        onTap: widget.enabled ? widget.onSubmit : null,
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            color: widget.enabled ? widget.color : Colors.grey,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 55, right: 16),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                left: 4 + _position * travel,
                child: GestureDetector(
                  onHorizontalDragUpdate: !widget.enabled
                      ? null
                      : (details) => setState(() {
                          _position = (_position + details.delta.dx / travel)
                              .clamp(0, 1);
                        }),
                  onHorizontalDragCancel: () => setState(() => _position = 0),
                  onHorizontalDragEnd: !widget.enabled
                      ? null
                      : (_) {
                          final complete = _position >= .9;
                          setState(() => _position = 0);
                          if (complete) widget.onSubmit();
                        },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.keyboard_double_arrow_right,
                      color: widget.color,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
