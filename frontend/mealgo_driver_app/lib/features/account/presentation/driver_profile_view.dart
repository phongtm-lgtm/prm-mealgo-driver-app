import 'package:flutter/material.dart';

class DriverProfileView extends StatelessWidget {
  const DriverProfileView({
    super.key,
    required this.name,
    required this.driverId,
    required this.phone,
    this.onEdit,
  });
  final String name, driverId, phone;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: .05,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 36,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name.trim().isEmpty ? 'Tài xế MealGo' : name,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Tài xế MealGo',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Thông tin cá nhân',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _field(context, 'Họ và tên', name),
                  _field(context, 'Mã tài xế', driverId),
                  _field(context, 'Số điện thoại liên hệ', phone),
                  Text(
                    'Bạn có thể cập nhật số liên hệ mà không ảnh hưởng đến số đăng nhập.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (onEdit != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onEdit,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.onSurface,
                        foregroundColor: theme.colorScheme.surface,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Chỉnh sửa thông tin'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        SelectableText(
          value.trim().isEmpty ? 'Chưa có thông tin' : value,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
