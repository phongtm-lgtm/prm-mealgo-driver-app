import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_dependencies.dart';
import '../../../app/backend_repositories.dart';
import '../../account/domain/account_repository.dart';
import '../../delivery/domain/delivery.dart';
import '../../driver/domain/driver.dart';

/// Session-level presentation state. Widgets never access data implementations.
class DriverController extends ChangeNotifier {
  DriverController(this._dependencies);
  final AppDependencies _dependencies;

  DriverProfile? profile;
  AccountSummary? summary;
  DriverSettings settings = const DriverSettings();
  List<DeliveryOrder> _available = [];
  List<DeliveryOrder> get available => List.unmodifiable(
    _available.where(
      (o) => !o.hasDistance || o.distance <= settings.maxDistance,
    ),
  );
  final List<DeliveryOrder> _history = [];
  List<DeliveryOrder> get history => List.unmodifiable(_history);
  DeliveryOrder? activeOrder;
  DeliveryOrder? selectedOrder;
  bool online = false;
  bool busy = false;
  bool initialized = false;
  bool showingActive = false;
  String? error;
  int completedToday = 0;
  int earnedToday = 0;
  int rejectedOffers = 0;
  DateTime? autoLockedUntil;
  bool get autoLocked => autoLockedUntil?.isAfter(DateTime.now()) ?? false;
  DeliveryOrder? offer;
  int offerSeconds = 0;
  Timer? _offerTimer;
  Timer? _pollTimer;
  bool _polling = false;
  BackendRepositories? get backend =>
      _dependencies.delivery is BackendRepositories
      ? _dependencies.delivery as BackendRepositories
      : null;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      return true;
    } catch (exception) {
      error = exception is StateError
          ? exception.message.toString()
          : exception.toString();
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> initialize() => _run(() async {
    final results = await Future.wait<Object>([
      _dependencies.driver.getProfile(),
      _dependencies.driver.getSettings(),
      _dependencies.account.getSummary(),
      _dependencies.delivery.getAvailable(),
    ]);
    profile = results[0] as DriverProfile;
    settings = results[1] as DriverSettings;
    summary = results[2] as AccountSummary;
    _available = results[3] as List<DeliveryOrder>;
    initialized = true;
    if (backend != null) {
      online = backend!.store.profile?['onlineStatus'] == 'ONLINE';
      activeOrder = await backend!.current();
      showingActive = activeOrder != null;
      _history
        ..clear()
        ..addAll(await backend!.history());
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollBackend(),
      );
    }
  });

  Future<void> _pollBackend() async {
    if (busy || _polling || _disposed || backend == null) return;
    _polling = true;
    try {
      _available = await backend!.getAvailable();
      activeOrder = await backend!.current();
      online = backend!.store.profile?['onlineStatus'] == 'ONLINE';
      if (!_available.any((o) => o.id == selectedOrder?.id))
        selectedOrder = null;
      _notify();
    } catch (e) {
      error = e.toString();
      _notify();
    } finally {
      _polling = false;
    }
  }

  Future<void> updateLocation() async {
    if (backend == null) return;
    final ok = await backend!.store.sendLocation();
    error = ok ? 'Đã cập nhật vị trí GPS thật.' : backend!.store.gpsError;
    _notify();
  }

  Future<bool> setOnline(bool value) => _run(() async {
    if (!value && activeOrder != null) {
      throw StateError('Hãy xử lý xong đơn hiện tại trước khi kết thúc ca.');
    }
    online = await _dependencies.driver.setOnline(value);
    if (!online) _clearOffer();
  });

  void selectOrder(DeliveryOrder? order) {
    selectedOrder = order;
    _notify();
  }

  void showActive(bool value) {
    showingActive = value;
    _notify();
  }

  Future<bool> refresh() => _run(() async {
    _available = await _dependencies.delivery.getAvailable();
    if (!_available.any((o) => o.id == selectedOrder?.id)) selectedOrder = null;
  });

  Future<bool> accept(DeliveryOrder order) => _run(() async {
    if (!online) throw StateError('Bạn cần vào ca trước khi nhận đơn.');
    if (activeOrder != null) throw StateError('Bạn đang có một đơn cần xử lý.');
    _clearOffer();
    activeOrder = await _dependencies.delivery.accept(order.id);
    _available = _available.where((o) => o.id != order.id).toList();
    selectedOrder = null;
    showingActive = true;
  });

  Future<bool> advance() => _run(() async {
    final order = activeOrder;
    if (order == null) return;
    final updated = await _dependencies.delivery.advance(order.id);
    if (updated.stage == DeliveryStage.completed) {
      completedToday++;
      earnedToday += updated.fee;
      _finish(updated);
    } else {
      activeOrder = updated;
    }
  });

  void _finish(DeliveryOrder order) {
    _history.insert(0, order);
    activeOrder = null;
    showingActive = false;
  }

  Future<bool> rejectActive(String reason) => _run(() async {
    final order = activeOrder;
    if (order == null) return;
    _finish(await _dependencies.delivery.reject(order.id, reason));
  });

  Future<bool> reportFailure(DeliveryReport report) => _run(() async {
    _finish(await _dependencies.delivery.report(report));
  });

  Future<bool> saveSettings(DriverSettings value) => _run(() async {
    settings = await _dependencies.driver.saveSettings(value);
    if (!settings.autoAccept) _clearOffer();
  });

  /// Explicit demo trigger instead of pretending to receive a server event.
  bool simulateOffer() {
    if (backend != null) {
      error =
          'Offer thật được đồng bộ từ máy chủ mỗi 5 giây; không tạo offer giả.';
      _notify();
      return false;
    }
    if (busy ||
        !online ||
        activeOrder != null ||
        offer != null ||
        !settings.autoAccept ||
        autoLocked ||
        available.isEmpty) {
      return false;
    }
    offer = available.first;
    offerSeconds = 15;
    _offerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      offerSeconds--;
      if (offerSeconds <= 0) {
        rejectOffer(timedOut: true);
      } else {
        _notify();
      }
    });
    _notify();
    return true;
  }

  void rejectOffer({bool timedOut = false}) {
    if (offer == null) return;
    _clearOffer();
    rejectedOffers++;
    if (rejectedOffers > 3) {
      autoLockedUntil = DateTime.now().add(const Duration(hours: 24));
    }
    error = autoLocked
        ? 'Tạm khóa nhận đơn tự động 24 giờ do từ chối quá 3 đơn (demo).'
        : timedOut
        ? 'Đã hết 15 giây. Đề nghị được chuyển cho tài xế khác (demo).'
        : 'Đã từ chối đề nghị (demo).';
    _notify();
  }

  void _clearOffer() {
    _offerTimer?.cancel();
    _offerTimer = null;
    offer = null;
    offerSeconds = 0;
  }

  void clearError() {
    error = null;
    _notify();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _disposed = true;
    _clearOffer();
    super.dispose();
  }
}
