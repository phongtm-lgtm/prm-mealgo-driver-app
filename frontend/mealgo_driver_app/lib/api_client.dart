import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Android emulator reaches the host machine through 10.0.2.2.
    // Override with --dart-define=API_BASE_URL=... for physical devices.
    defaultValue: 'http://10.0.2.2:8080',
  );
  final http.Client client;
  String? token;
  void Function()? onUnauthorized;
  Future<bool> Function()? onRefresh;
  Future<bool>? _refreshing;
  Future<bool> refreshSession(String expiredToken) async {
    if (token != expiredToken) return token != null;
    if (onRefresh == null) return false;
    final pending = _refreshing ??= onRefresh!();
    try {
      return await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }

  ApiClient({http.Client? client})
    : client = _SessionClient(client ?? http.Client()) {
    (this.client as _SessionClient).owner = this;
  }

  Future<dynamic> request(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl/api/v1$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null && !path.startsWith('/auth/')) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      return decode(await http.Response.fromStream(response));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'Không kết nối được máy chủ');
    }
  }

  dynamic decode(http.Response response) {
    dynamic data;
    try {
      data = response.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 &&
          token != null &&
          !(response.request?.url.path.startsWith('/api/v1/auth/') ?? false))
        onUnauthorized?.call();
      throw ApiException(
        response.statusCode,
        data is Map
            ? (data['detail'] ??
                      data['message'] ??
                      'Yêu cầu thất bại (${response.statusCode})')
                  .toString()
            : 'Yêu cầu thất bại (${response.statusCode})',
      );
    }
    return data;
  }

  Future<dynamic> reportFailure(
    String deliveryId,
    Map<String, String> fields,
    List<int> bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/api/v1/drivers/me/deliveries/$deliveryId/failure-report',
      ),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    try {
      return decode(
        await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 40)),
        ),
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'Không gửi được ảnh. Giữ nguyên báo cáo và thử lại.',
      );
    }
  }

  void close() => client.close();

  Future<Map<String, dynamic>> deliveryIncident(
    String deliveryId,
    Map<String, String> fields,
    List<int>? bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/drivers/me/deliveries/$deliveryId/incident'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (bytes != null)
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: filename),
      );
    try {
      return Map<String, dynamic>.from(
        decode(
          await http.Response.fromStream(
            await client.send(request).timeout(const Duration(seconds: 40)),
          ),
        ) as Map,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'Không gửi được sự cố. Giữ nguyên nội dung và thử lại.',
      );
    }
  }

  Future<void> verifyFace(List<int> bytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/drivers/me/face-verification'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final data = decode(
        await http.Response.fromStream(response)
            .timeout(const Duration(seconds: 30)),
      );
      if (data is! Map || data['success'] != true) {
        throw ApiException(
          400,
          'Xác thực không thành công. Vui lòng chụp lại.',
        );
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'Không gửi được ảnh xác thực. Vui lòng thử lại.');
    }
  }

  Future<Uint8List> evidence(String deliveryId) async {
    final response = await client
        .get(
          Uri.parse(
            '$baseUrl/api/v1/drivers/me/deliveries/$deliveryId/failure-report/evidence',
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      decode(response);
    }
    return response.bodyBytes;
  }
}

/// Buffers request bytes so JSON and image uploads can be retried once after 401.
class _SessionClient extends http.BaseClient {
  _SessionClient(this.inner);
  final http.Client inner;
  late ApiClient owner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final originalToken = owner.token;
    Future<http.StreamedResponse> sendCopy({bool retry = false}) {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = bytes
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects;
      if (retry && owner.token != null)
        copy.headers['Authorization'] = 'Bearer ${owner.token}';
      return inner.send(copy);
    }

    final response = await sendCopy();
    if (response.statusCode != 401 ||
        request.url.path.startsWith('/api/v1/auth/') ||
        originalToken == null ||
        owner.onRefresh == null)
      return response;
    await response.stream.drain<void>();
    bool refreshed;
    if (owner.token != originalToken) {
      refreshed = owner.token != null;
    } else {
      refreshed = await owner.refreshSession(originalToken);
    }
    if (refreshed) return sendCopy(retry: true);
    return http.StreamedResponse(const Stream<List<int>>.empty(), 401);
  }

  @override
  void close() => inner.close();
}
