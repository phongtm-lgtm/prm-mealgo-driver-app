import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../api_client.dart';
import 'widgets/onboarding_components.dart';

class FaceVerificationPage extends StatefulWidget {
  const FaceVerificationPage({super.key, required this.verify});
  final Future<void> Function(List<int> bytes, String filename) verify;

  @override
  State<FaceVerificationPage> createState() => _FaceVerificationPageState();
}

class _FaceVerificationPageState extends State<FaceVerificationPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Uint8List? _photo;
  String? _error;
  bool _opening = false, _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _releaseCamera() async {
    _generation++;
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _camera != null) {
      _releaseCamera();
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _open() async {
    if (_opening || _busy) return;
    setState(() {
      _opening = true;
      _error = null;
      _photo = null;
    });
    await _releaseCamera();
    final generation = _generation;
    CameraController? camera;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Thiết bị không có camera.');
      final front = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      camera = CameraController(
        front.isEmpty ? cameras.first : front.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted || generation != _generation) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } catch (_) {
      await camera?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Chưa thể mở camera. Hãy cho phép truy cập camera trong cài đặt, đóng ứng dụng khác đang dùng camera rồi thử lại.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      await _releaseCamera();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không chụp được ảnh. Vui lòng mở lại camera.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.verify(photo, 'face.jpg');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException && e.status == 401
              ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
              : 'Chưa thể gửi ảnh. Kiểm tra kết nối và thử lại nhé.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OnboardingStyle.background,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Quay lại',
                      onPressed: _busy || _opening
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.arrow_back_rounded, size: 21),
                    ),
                    const Expanded(
                      child: Text(
                        'Xác minh trước ca làm',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: OnboardingStyle.ink,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: OnboardingStyle.orange,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    const Text(
                      'Xác nhận khuôn mặt',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.25,
                        letterSpacing: -0.6,
                        fontWeight: FontWeight.w800,
                        color: OnboardingStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đưa khuôn mặt vào khung hình để hoàn tất bước kiểm tra trước khi bắt đầu ca làm.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: OnboardingStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 1.14,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF252624)),
                            if (_photo != null)
                              Image.memory(_photo!, fit: BoxFit.contain)
                            else if (_camera != null)
                              Center(child: CameraPreview(_camera!)),
                            if (_photo == null)
                              Positioned.fill(
                                bottom: 40,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _FaceGuidePainter(
                                      silhouette: _camera == null,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 16,
                              child: Text(
                                _photo != null
                                    ? 'Kiểm tra ảnh trước khi xác nhận'
                                    : 'Đặt khuôn mặt trong khung hình',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 5),
                                  ],
                                ),
                              ),
                            ),
                            if (_opening || _busy)
                              const ColoredBox(
                                color: Color(0x66000000),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: OnboardingStyle.orange,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: OnboardingStyle.orange,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Để có ảnh rõ nét',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: OnboardingStyle.ink,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Giữ điện thoại ngang tầm mắt, ở nơi đủ sáng và tránh che khuất khuôn mặt.',
                                style: TextStyle(
                                  color: OnboardingStyle.muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB64E47),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: OnboardingStyle.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _opening || _busy
                            ? null
                            : _photo != null
                            ? _submit
                            : _camera != null
                            ? _capture
                            : _open,
                        icon: _opening || _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: OnboardingStyle.muted,
                                ),
                              )
                            : Icon(
                                _photo != null
                                    ? Icons.check_rounded
                                    : Icons.photo_camera_outlined,
                                size: 19,
                              ),
                        label: Text(
                          _opening
                              ? 'Đang mở camera…'
                              : _busy
                              ? 'Đang xử lý…'
                              : _photo != null
                              ? 'Xác nhận & vào ca'
                              : _camera != null
                              ? 'Chụp ảnh'
                              : 'Mở camera',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_photo != null)
                      TextButton(
                        onPressed: _busy ? null : _open,
                        child: const Text(
                          'Chụp lại',
                          style: TextStyle(color: OnboardingStyle.orange),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter({required this.silhouette});
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 0.43;
    final height = math.min(size.height * 0.79, width * 1.35);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
    final oval = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(width / 2)));
    final dashed = Paint()
      ..color = const Color(0xFFD9DBD8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in oval.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 13) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 7, metric.length)),
          dashed,
        );
      }
    }
    if (silhouette) {
      final fill = Paint()..color = const Color(0xFF969A9D);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rect.center.dx, rect.top + height * .38),
          width: width * .45,
          height: height * .35,
        ),
        fill,
      );
      final shoulders = Path()
        ..moveTo(rect.left + width * .12, rect.bottom - height * .10)
        ..cubicTo(
          rect.left + width * .10,
          rect.top + height * .55,
          rect.right - width * .10,
          rect.top + height * .55,
          rect.right - width * .12,
          rect.bottom - height * .10,
        )
        ..close();
      canvas.drawPath(shoulders, fill);
    }
    final corner = Paint()
      ..color = OnboardingStyle.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (final point in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final dx = point.dx == rect.left ? 1.0 : -1.0;
      final dy = point.dy == rect.top ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy + 29 * dy)
          ..lineTo(point.dx, point.dy + 13 * dy)
          ..quadraticBezierTo(point.dx, point.dy, point.dx + 13 * dx, point.dy)
          ..lineTo(point.dx + 29 * dx, point.dy),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) =>
      silhouette != oldDelegate.silhouette;
}
