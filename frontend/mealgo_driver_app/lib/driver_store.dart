import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import 'api_client.dart';

class DriverStore extends ChangeNotifier {
  final ApiClient api;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? profile, delivery;
  List<dynamic> offers = [], history = [];
  bool initializing = true, busy = false, refreshing = false;
  bool authenticated = false, needsRegistration = false, loadingHistory = false;
  bool hasNextHistory = false;
  Map<String, dynamic>? application;
  bool get needsApplication =>
      authenticated &&
      (needsRegistration ||
          (profile != null && profile!['accountStatus'] != 'ACTIVE'));
  int historyPage = 0;
  String? error, gpsError;
  Position? position;
  DateTime? lastSync;
  Timer? _poll, _gps;
  String? _session;
  String? _refreshToken;
  int _sequence = 0, _generation = 0;
  bool _sendingGps = false, _disposed = false;

  DriverStore({ApiClient? api, FlutterSecureStorage? storage})
    : api = api ?? ApiClient(),
      storage = storage ?? const FlutterSecureStorage() {
    this.api.onUnauthorized = () {
      unawaited(logout());
    };
    this.api.onRefresh = _refreshAccessToken;
  }
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    try {
      api.token = await storage.read(key: 'access_token');
      _refreshToken = await storage.read(key: 'refresh_token');
      if (api.token != null) {
        authenticated = true;
        await refresh();
        if (authenticated) _startPolling();
      }
    } catch (_) {
      error = 'Không đọc được phiên đăng nhập. Vui lòng đăng nhập lại.';
    }
    initializing = false;
    changed();
  }

  Future<void> login(String phoneNumber, String password) async {
    await run(() async {
      if (!RegExp(r'^(?:0|\+84)[35789][0-9]{8}$')
          .hasMatch(phoneNumber.trim())) {
        throw ApiException(400, 'Số điện thoại di động Việt Nam không hợp lệ.');
      }
      final data = await api.request('POST', '/auth/login', {
        'phoneNumber': phoneNumber.trim(),
        'password': password,
      });
      if (data['role'] != 'DRIVER')
        throw ApiException(403, 'Tài khoản này không phải tài xế.');
      await storage.write(key: 'access_token', value: data['accessToken']);
      _refreshToken = data['refreshToken'] as String?;
      if (_refreshToken != null) {
        await storage.write(key: 'refresh_token', value: _refreshToken);
      } else {
        await storage.delete(key: 'refresh_token');
      }
      api.token = data['accessToken'];
      authenticated = true;
      await refresh();
      if (authenticated) _startPolling();
    });
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(refresh());
    });
    _gps?.cancel();
    _gps = Timer.periodic(const Duration(seconds: 10), (_) {
      if (profile?['onlineStatus'] == 'ONLINE' || delivery != null)
        unawaited(sendLocation());
    });
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    _refreshToken = null;
    _generation++;
    _poll?.cancel();
    _gps?.cancel();
    api.token = null;
    authenticated = false;
    needsRegistration = false;
    application = null;
    profile = null;
    delivery = null;
    offers = [];
    history = [];
    _session = null;
    position = null;
    gpsError = null;
    error = null;
    try {
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
    } catch (_) {
      /* Session remains cleared in memory. */
    }
    changed();
    if (refresh != null) {
      try {
        await api.request('POST', '/auth/logout', {'refreshToken': refresh});
      } catch (_) {
        // Offline logout still clears the local session.
      }
    }
  }

  Future<bool> _refreshAccessToken() async {
    final refresh = _refreshToken;
    final generation = _generation;
    if (refresh == null) return false;
    try {
      final data = await api.request('POST', '/auth/refresh', {
        'refreshToken': refresh,
      });
      if (generation != _generation) {
        try {
          await api.request('POST', '/auth/logout', {
            'refreshToken': data['refreshToken'],
          });
        } catch (_) {}
        return false;
      }
      final access = data['accessToken'] as String;
      final rotated = data['refreshToken'] as String;
      await storage.write(key: 'refresh_token', value: rotated);
      await storage.write(key: 'access_token', value: access);
      if (generation != _generation) {
        await storage.delete(key: 'access_token');
        await storage.delete(key: 'refresh_token');
        return false;
      }
      _refreshToken = rotated;
      api.token = access;
      return true;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 400) return false;
      rethrow;
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    changed();
    try {
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> refresh() async {
    if (!authenticated || refreshing || busy && profile != null) return;
    refreshing = true;
    final generation = _generation;
    try {
      final result = await api.request('GET', '/drivers/me');
      if (generation != _generation) return;
      profile = Map<String, dynamic>.from(result);
      needsRegistration = false;
      final values = await Future.wait([
        api.request('GET', '/drivers/me/deliveries/current'),
        api.request('GET', '/drivers/me/offers'),
      ]);
      if (generation != _generation) return;
      delivery = values[0] == null
          ? null
          : Map<String, dynamic>.from(values[0]);
      offers = List<dynamic>.from(values[1]);
      lastSync = DateTime.now();
      error = null;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      if (e.status == 404 && profile == null) {
        needsRegistration = true;
      } else {
        error = e.message;
      }
    } catch (e) {
      if (generation == _generation) error = e.toString();
    } finally {
      refreshing = false;
      changed();
    }
  }

  Future<void> saveProfile(String name, String phone) => run(() async {
    await api.request(
      needsRegistration ? 'POST' : 'PUT',
      needsRegistration ? '/drivers' : '/drivers/me/profile',
      {'fullName': name, 'phoneNumber': phone},
    );
    profile = Map<String, dynamic>.from(
      await api.request('GET', '/drivers/me'),
    );
    needsRegistration = false;
  });

  Future<void> setOnline(bool online) => run(() async {
    profile = Map<String, dynamic>.from(
      await api.request('PUT', '/drivers/me/online-status', {'online': online}),
    );
    if (online) await sendLocation();
  });

  Future<void> respond(String assignment, bool accept) => run(() async {
    await api.request(
      'POST',
      '/drivers/me/offers/$assignment/${accept ? 'accept' : 'reject'}',
    );
    delivery = await api.request('GET', '/drivers/me/deliveries/current');
    offers = await api.request('GET', '/drivers/me/offers');
  });

  Future<bool> sendLocation() async {
    if (_sendingGps || !authenticated || profile == null) return false;
    _sendingGps = true;
    final generation = _generation;
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('Vui lòng bật dịch vụ vị trí trên thiết bị.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Chưa có quyền GPS. Cho phép vị trí trong cài đặt trình duyệt/thiết bị.',
        );
      }
      final sample = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (generation != _generation) return false;
      _session ??= (await api.request(
        'POST',
        '/drivers/me/tracking-session',
      ))['trackingSessionId'];
      if (generation != _generation) return false;
      await api.request('PUT', '/drivers/me/location', {
        'trackingSessionId': _session,
        'sequence': ++_sequence,
        'latitude': sample.latitude,
        'longitude': sample.longitude,
        'accuracyMeters': sample.accuracy,
        'recordedAt': sample.timestamp.toUtc().toIso8601String(),
      });
      position = sample;
      gpsError = null;
      return true;
    } on ApiException catch (e) {
      if (generation == _generation) {
        if (e.status == 409) {
          _session = null;
          _sequence = 0;
        }
        gpsError = e.message;
      }
      return false;
    } catch (e) {
      if (generation == _generation)
        gpsError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _sendingGps = false;
      changed();
    }
  }

  Future<void> action(String action) => run(() async {
    if (!await sendLocation())
      throw Exception(gpsError ?? 'Chưa cập nhật được GPS. Hãy thử lại.');
    delivery = Map<String, dynamic>.from(
      await api.request(
        'POST',
        '/drivers/me/deliveries/${delivery!['deliveryId']}/$action',
      ),
    );
    if (delivery?['status'] == 'DELIVERED') {
      delivery = null;
      await loadHistory();
    }
  });

  Future<void> loadHistory({bool next = false}) async {
    if (loadingHistory) return;
    loadingHistory = true;
    changed();
    try {
      final page = next ? historyPage + 1 : 0;
      final data = await api.request(
        'GET',
        '/drivers/me/deliveries/history?page=$page&size=20',
      );
      history = next
          ? [...history, ...data['items']]
          : List<dynamic>.from(data['items']);
      historyPage = page;
      hasNextHistory = data['hasNext'];
    } catch (e) {
      error = e.toString();
    } finally {
      loadingHistory = false;
      changed();
    }
  }

  Future<bool> reportFailure(
    String requestId,
    String reason,
    String note,
    List<int> bytes,
    String filename,
  ) async {
    bool success = false;
    await run(() async {
      final d = delivery!;
      await api.reportFailure(
        d['deliveryId'],
        {
          'assignmentId': d['assignmentId'],
          'requestId': requestId,
          'reason': reason,
          if (note.trim().isNotEmpty) 'note': note.trim(),
        },
        bytes,
        filename,
      );
      delivery = null;
      success = true;
      await loadHistory();
    });
    return success;
  }

  static String uuid() {
    final r = Random.secure();
    final b = List.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _gps?.cancel();
    api.close();
    super.dispose();
  }
}
