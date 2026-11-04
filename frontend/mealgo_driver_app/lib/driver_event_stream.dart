import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// SSE invalidations, not order data. A new connection always triggers a refresh.
class DriverEventStream {
  DriverEventStream(this.api, this.onChanged);

  final ApiClient api;
  final void Function() onChanged;
  http.Client? _client;
  Timer? _retry;
  bool _disposed = false;
  int _failures = 0;

  Future<void> connect() async {
    if (_disposed) return;
    final token = api.token;
    if (token == null) return;
    final client = http.Client();
    _client = client;
    try {
      final request = http.Request(
        'GET',
        Uri.parse('${ApiClient.baseUrl}/api/v1/drivers/me/events'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      });
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;
      if (response.statusCode == 401) {
        if (!await api.refreshSession(token)) api.onUnauthorized?.call();
        return;
      }
      if (response.statusCode != 200) {
        throw ApiException(response.statusCode, 'Không kết nối được SSE.');
      }
      if (!(response.headers['content-type'] ?? '').startsWith(
        'text/event-stream',
      )) {
        throw StateError('Expected an SSE stream');
      }
      _failures = 0;
      String event = '';
      await for (final line
          in response.stream
              .timeout(const Duration(seconds: 45))
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (_disposed) break;
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.isEmpty) {
          if (event == 'connected' || event == 'orders-changed') onChanged();
          event = '';
        }
      }
    } catch (_) {
      // Polling remains available while the event connection is unavailable.
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      if (!_disposed && api.token != null) {
        _failures = (_failures + 1).clamp(1, 5);
        _retry = Timer(Duration(seconds: 1 << _failures), connect);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _client?.close();
  }
}
