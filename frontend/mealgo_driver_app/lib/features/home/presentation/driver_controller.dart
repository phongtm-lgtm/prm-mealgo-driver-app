import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_dependencies.dart';
import '../../../app/backend_repositories.dart';
import '../../../driver_event_stream.dart';
import '../../../api_client.dart';
import '../../account/domain/account_repository.dart';
import '../../account/presentation/account_state.dart';
import '../../delivery/domain/delivery.dart';
import '../../driver/domain/driver.dart';

/// Session-level presentation state. Widgets never access data implementations.
class DriverController extends ChangeNotifier {
  DriverController(this._dependencies);
  final AppDependencies _dependencies;
  late final AccountState? account =
      _dependencies.account is AccountDataRepository
      ? AccountState(_dependencies.account as AccountDataRepository)
      : null;

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
  Map<String, dynamic>? lastIncident;
  bool online = false;
  bool busy = false;
  bool refreshingOffers = false;
  bool initialized = false;
  bool showingActive = false;
  String? error;
  bool lastRequestConnectionFailed = false;
  bool serverUnavailable = false;

  bool _isServerFailure(Object exception) =>
      exception is ApiException &&
      (exception.status == 0 || exception.status >= 500);
  int completedToday = 0;
  int earnedToday = 0;
  int rejectedOffers = 0;
  DateTime? autoLockedUntil;
  bool get autoLocked => autoLockedUntil?.isAfter(DateTime.now()) ?? false;
  DeliveryOrder? offer;
  int offerSeconds = 0;
  Timer? _offerTimer;
  Timer? _pollTimer;
  DriverEventStream? _events;
  bool _refreshPending = false;
  bool _polling = false;
  int _revision = 0;
  String? _trackedDeliveryId;
  String? _cancellationMessage;
  String? get cancellationMessage => _cancellationMessage;
  String? takeCancellationMessage() {
    final message = _cancellationMessage;
    _cancellationMessage = null;
    return message;
  }
  bool get canRefreshFreePick =>
      online && !showingActive && activeOrder == null && offer == null;
  BackendRepositories? get backend =>
      _dependencies.delivery is BackendRepositories
      ? _dependencies.delivery as BackendRepositories
      : null;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action, {bool refreshOffers = false}) async {
    if (busy || _disposed) return false;
    // Invalidate reads started before a driver action.
    _revision++;
    if (_polling) _refreshPending = true;
    busy = true;
    refreshingOffers = refreshOffers;
    lastRequestConnectionFailed = false;
    error = null;
    _notify();
    try {
      await action();
      return true;
    } catch (exception) {
      lastRequestConnectionFailed =
          exception is ApiException && exception.status == 0;
      if (_isServerFailure(exception)) serverUnavailable = true;
      error = exception is StateError
          ? exception.message.toString()
          : exception.toString();
      return false;
    } finally {
      busy = false;
      refreshingOffers = false;
      _notify();
      if (_refreshPending && !_disposed) _pollBackend();
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
      _trackedDeliveryId = await backend!.store.storage.read(key: _trackingKey);
      await _syncCurrent(await backend!.current(), _revision);
      showingActive = activeOrder != null;
      _history
        ..clear()
        ..addAll(await backend!.history());
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => _pollBackend(),
      );
      _events ??= DriverEventStream(backend!.store.api, () {
        syncFromServer();
      })..connect();
    }
    serverUnavailable = false;
  });

  String get _trackingKey => 'active_delivery_${profile!.id}';

  Future<void> _rememberActive(String? id) async {
    if (backend == null || _trackedDeliveryId == id) return;
    _trackedDeliveryId = id;
    if (id == null) {
      await backend!.store.storage.delete(key: _trackingKey);
    } else {
      await backend!.store.storage.write(key: _trackingKey, value: id);
    }
  }

  Future<void> _syncCurrent(DeliveryOrder? current, int revision) async {
    final previous = _trackedDeliveryId;
    final ended = previous != null && previous != current?.id
        ? await backend!.pastDelivery(previous)
        : null;
    if (_disposed || revision != _revision) return;
    activeOrder = current;
    if (previous != null && previous != current?.id) {
      selectedOrder = null;
      showingActive = current != null;
      if (ended?.stage == DeliveryStage.cancelled) {
        _cancellationMessage = switch (ended?.cancellationCode) {
          'CUSTOMER_CANCELLED' => 'Khách hàng đã hủy đơn này',
          'RESTAURANT_OUT_OF_STOCK' => 'Nhà hàng đã hủy đơn do hết món',
          'RESTAURANT_ISSUE' => 'Nhà hàng đã hủy đơn do sự cố tại quán',
          _ => 'Đơn hàng đã được hủy',
        };
        _history.removeWhere((o) => o.id == ended!.id);
        _history.insert(0, ended!);
        account?.invalidate();
      }
    }
    await _rememberActive(current?.id);
  }

  void syncFromServer() {
    if (backend == null || !initialized || _disposed) return;
    _refreshPending = true;
    _pollBackend();
  }

  Future<void> _pollBackend() async {
    if (busy || _polling || _disposed || backend == null) return;
    _polling = true;
    _refreshPending = false;
    final revision = _revision;
    try {
      final offers = await backend!.getAvailable();
      final current = await backend!.current();
      if (_disposed || revision != _revision) return;
      await _syncCurrent(current, revision);
      if (_disposed || revision != _revision) return;
      _available = offers;
      online = backend!.store.profile?['onlineStatus'] == 'ONLINE';
      if (!_available.any((o) => o.id == selectedOrder?.id))
        selectedOrder = null;
      if (serverUnavailable) error = null;
      serverUnavailable = false;
      _notify();
    } catch (e) {
      if (_disposed || revision != _revision) return;
      if (_isServerFailure(e)) serverUnavailable = true;
      error = e.toString();
      _notify();
    } finally {
      _polling = false;
      if (_refreshPending && !_disposed && !busy) _pollBackend();
    }
  }

  Future<void> updateLocation() async {
    if (backend == null) return;
    final ok = await backend!.store.sendLocation();
    error = ok ? 'Đã cập nhật vị trí của bạn.' : backend!.store.gpsError;
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

  Future<bool> refreshFreePick(DeliveryOrder? displayed) async {
    if (!canRefreshFreePick) return false;
    return _run(() async {
      _available = await _dependencies.delivery.refreshOffers([
        if (displayed != null) displayed,
      ]);
      selectedOrder = null;
    }, refreshOffers: true);
  }

  Future<bool> accept(DeliveryOrder order) => _run(() async {
    if (!online) throw StateError('Bạn cần vào ca trước khi nhận đơn.');
    if (activeOrder != null) throw StateError('Bạn đang có một đơn cần xử lý.');
    _clearOffer();
    activeOrder = await _dependencies.delivery.accept(order.id);
    _available = _available.where((o) => o.id != order.id).toList();
    selectedOrder = null;
    showingActive = true;
    await _rememberActive(activeOrder!.id);
  });

  Future<bool> advance() => _run(() async {
    final order = activeOrder;
    if (order == null) return;
    final updated = await _dependencies.delivery.advance(order.id);
    if (updated.stage == DeliveryStage.completed) {
      completedToday++;
      earnedToday += updated.fee;
      _finish(updated);
      await _rememberActive(null);
      account?.invalidate();
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

  Future<bool> submitIncident(
    String deliveryId,
    String reason,
    String note,
    String requestId,
    List<int>? bytes,
    String filename,
  ) => _run(() async {
    if (activeOrder?.id != deliveryId || !activeOrder!.canRelease)
      throw StateError('Chuyến hiện tại đã thay đổi. Hãy làm mới.');
    final repository = _dependencies.delivery;
    if (repository is! DeliveryIncidentRepository)
      throw StateError('Chưa thể gửi thông tin sự cố. Vui lòng thử lại.');
    lastIncident = await (repository as DeliveryIncidentRepository)
        .submitIncident(deliveryId, reason, note, requestId, bytes, filename);
    activeOrder = null;
    selectedOrder = null;
    showingActive = false;
    await _rememberActive(null);
    syncFromServer();
    account?.invalidate();
  });

  Future<bool> reportFailure(DeliveryReport report) => _run(() async {
    if (activeOrder?.id != report.orderId) {
      throw StateError('Chuyến hiện tại đã thay đổi. Hãy làm mới.');
    }
    _finish(await _dependencies.delivery.report(report));
    await _rememberActive(null);
    account?.invalidate();
  });

  Future<bool> updateProfile(String name, String phone) => _run(() async {
    final repository = _dependencies.account as AccountDataRepository;
    await repository.updateProfile(name, phone);
    profile = await _dependencies.driver.getProfile();
  });

  Future<bool> saveSettings(DriverSettings value) => _run(() async {
    settings = await _dependencies.driver.saveSettings(value);
    if (!settings.autoAccept) _clearOffer();
  });

  /// Explicit demo trigger instead of pretending to receive a server event.
  bool simulateOffer() {
    if (backend != null) {
      error = 'Đơn mới sẽ tự cập nhật khi có lời mời dành cho bạn.';
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
    account?.dispose();
    _pollTimer?.cancel();
    _events?.dispose();
    _disposed = true;
    _clearOffer();
    super.dispose();
  }
}
