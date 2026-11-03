import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_widgets.dart';

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
    } catch (e) {
      await camera?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = e is CameraException
              ? 'Không truy cập được camera (${e.code}). Cho phép Camera trong cài đặt trình duyệt/thiết bị rồi thử lại. Nếu không có camera hoặc camera đang được ứng dụng khác dùng, hãy kiểm tra lại thiết bị.'
              : e.toString(),
        );
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _opening = false);
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
      if (mounted)
        setState(() => _error = 'Không chụp được ảnh. Vui lòng mở lại camera.');
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
      if (mounted) setState(() => _error = e.toString());
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
    appBar: AppBar(title: const Text('Xác thực khuôn mặt')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const DemoNotice(
              text: 'Camera thật • Backend hiện luôn trả thành công, chưa nhận diện khuôn mặt.',
            ),
            const SizedBox(height: 16),
            const Text(
              'App cần quyền truy cập camera để chụp ảnh vào ca. Không dùng microphone. Ảnh chỉ được gửi khi bạn nhấn “Gửi ảnh & vào ca”; backend không lưu ảnh.',
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: Colors.black87,
                child: _photo != null
                    ? Image.memory(_photo!, fit: BoxFit.contain)
                    : _camera != null
                    ? CameraPreview(_camera!)
                    : const Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white70,
                          size: 80,
                        ),
                      ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            if (_opening || _busy)
              const Center(child: CircularProgressIndicator()),
            if (_photo != null) ...[
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Gửi ảnh & vào ca'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _open,
                child: const Text('Chụp lại'),
              ),
            ] else if (_camera != null)
              FilledButton(
                onPressed: _busy ? null : _capture,
                child: const Text('Chụp ảnh'),
              )
            else
              FilledButton(
                onPressed: _opening || _busy ? null : _open,
                child: const Text('Cho phép & mở camera'),
              ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Hủy và quay lại'),
            ),
          ],
        ),
      ),
    ),
  );
}
