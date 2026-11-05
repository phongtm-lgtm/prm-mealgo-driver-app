import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/account/presentation/account_page.dart';
import 'features/home/presentation/driver_controller.dart';
import 'features/home/presentation/home_page.dart';
import 'features/home/presentation/login_page.dart';
import 'driver_store.dart';
import 'features/home/presentation/application_page.dart';

class MealGoDriverApp extends StatefulWidget {
  const MealGoDriverApp({super.key, this.dependencies});

  final AppDependencies? dependencies;

  @override
  State<MealGoDriverApp> createState() => _MealGoDriverAppState();
}

class _MealGoDriverAppState extends State<MealGoDriverApp> {
  final _store = DriverStore();
  DriverController? _controller;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasAuthenticated = false;
  @override
  void initState() {
    super.initState();
    NotificationService.instance.init(
      onSelectNotification: _handleNotificationPayload,
    );
    if (widget.dependencies != null) {
      _controller = DriverController(widget.dependencies!)..initialize();
    } else {
      _store.addListener(_sessionChanged);
      _store.init();
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || !mounted) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    if (payload.startsWith('offer:') || payload.startsWith('cancellation:')) {
      nav.popUntil((route) => route.isFirst);
    } else if (payload.startsWith('backend_notification:') ||
        payload.startsWith('delivery_completed:')) {
      if (_controller != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => AccountPage(
              controller: _controller!,
              section: AccountSection.notifications,
            ),
          ),
        );
      }
    }
  }

  void _sessionChanged() {
    if (_wasAuthenticated && !_store.authenticated) {
      // Drop every authenticated route, including pages above the dashboard.
      _navigatorKey = GlobalKey<NavigatorState>();
    }
    _wasAuthenticated = _store.authenticated;
    if (_store.authenticated &&
        !_store.initializing &&
        !_store.needsApplication &&
        _store.profile != null &&
        _controller == null) {
      _controller = DriverController(AppDependencies.backend(_store))
        ..initialize();
    } else if (!_store.authenticated && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_sessionChanged);
    _controller?.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'MealGo Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _store.needsApplication
          ? ApplicationPage(store: _store)
          : _controller != null
          ? HomePage(
              controller: _controller!,
              onLogout: widget.dependencies == null ? _store.logout : null,
            )
          : _store.initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : LoginPage(store: _store),
    );
  }
}
