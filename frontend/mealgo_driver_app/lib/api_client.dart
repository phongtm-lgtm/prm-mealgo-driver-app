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
    defaultValue: 'http://localhost:8080',
  );
  final http.Client client;
  String? token;
  void Function()? onUnauthorized;
  ApiClient({http.Client? client}) : client = client ?? http.Client();

  Future<dynamic> request(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl/api/v1$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      return decode(await http.Response.fromStream(response));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'Không kết nối được máy chủ',
      );
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
      if (response.statusCode == 401 && token != null) onUnauthorized?.call();
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
