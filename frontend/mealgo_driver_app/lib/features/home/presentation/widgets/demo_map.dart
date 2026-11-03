import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../delivery/domain/delivery.dart';

/// Offline vector illustration, deliberately independent of a map SDK.
class DemoMap extends StatelessWidget {
  const DemoMap({
    super.key,
    required this.orders,
    required this.onSelected,
    this.active = false,
  });
  final List<DeliveryOrder> orders;
  final ValueChanged<DeliveryOrder> onSelected;
  final bool active;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MapPainter(active))),
        const Positioned(
          top: 24,
          left: 20,
          child: Text(
            'QUẬN 3',
            style: TextStyle(
              color: Color(0xFF89958D),
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const Positioned(
          top: 110,
          right: 20,
          child: Text(
            'Công viên\nLê Văn Tám',
            style: TextStyle(color: Color(0xFF57936C), fontSize: 12),
          ),
        ),
        Positioned(
          top: box.maxHeight * .45,
          left: box.maxWidth * .24,
          child: const Text(
            'TP. Hồ Chí Minh',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Color(0xFF78877D),
            ),
          ),
        ),
        Positioned(
          top: box.maxHeight * .58,
          left: box.maxWidth * .5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: .12),
            ),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Icon(Icons.navigation, color: AppColors.primary, size: 22),
            ),
          ),
        ),
        for (var i = 0; i < orders.length; i++)
          Positioned(
            top: box.maxHeight * (.16 + i * .12),
            left: box.maxWidth * (.2 + i * .23),
            child: IconButton.filled(
              tooltip: orders[i].restaurant,
              onPressed: () => onSelected(orders[i]),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.teal,
                side: const BorderSide(color: Colors.white, width: 2),
              ),
              icon: const Icon(Icons.storefront, size: 22),
            ),
          ),
        const Positioned(bottom: 12, left: 16, child: StatusPillMap()),
      ],
    ),
  );
}

class StatusPillMap extends StatelessWidget {
  const StatusPillMap({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Text(
      '●  Q.1 • Khu vực sôi động   |   BẢN ĐỒ DEMO',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.green,
      ),
    ),
  );
}

class _MapPainter extends CustomPainter {
  const _MapPainter(this.active);
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFE8EEE7), BlendMode.srcOver);
    final park = Paint()..color = const Color(0xFFCFE5CF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .62, 30, 95, 130),
        const Radius.circular(24),
      ),
      park,
    );
    final river = Path()
      ..moveTo(size.width * .85, -20)
      ..cubicTo(
        size.width * .2,
        size.height * .3,
        size.width * 1.3,
        size.height * .55,
        size.width * .8,
        size.height + 20,
      );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFFB9DFE8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 35,
    );
    for (var i = -5; i < 15; i++) {
      final x = i * 48.0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 160, size.height),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 9,
      );
      canvas.drawLine(
        Offset(0, x),
        Offset(size.width, x + 100),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 7,
      );
    }
    final road = Path()
      ..moveTo(-10, size.height * .8)
      ..lineTo(size.width * .35, size.height * .5)
      ..lineTo(size.width * .3, 0);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFEFD19A)
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFFFF1C8)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke,
    );
    if (active) {
      final route = Path()
        ..moveTo(size.width * .54, size.height * .65)
        ..lineTo(size.width * .35, size.height * .5)
        ..lineTo(size.width * .23, size.height * .22);
      canvas.drawPath(
        route,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => oldDelegate.active != active;
}
