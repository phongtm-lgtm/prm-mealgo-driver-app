import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'package:vietmap_flutter_plugin/vietmap_flutter_plugin.dart' as vietmap;

import '../../../core/theme/app_theme.dart';
import '../../../driver_store.dart';
import '../domain/delivery.dart';

class DeliveryMap extends StatefulWidget {
  const DeliveryMap({super.key, required this.order, required this.store});

  final DeliveryOrder order;
  final DriverStore store;

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  static const _tileKey = String.fromEnvironment('VIETMAP_TILEMAP_KEY');
  static const _routeKey = String.fromEnvironment('VIETMAP_ROUTE_KEY');

  VietmapController? _map;
  bool _styleLoaded = false;
  bool _routeLoading = false;
  bool _routeUnavailable = false;
  bool _following = false;

  List<LatLng> _route = const [];
  List<Line> _lines = const [];
  LatLng? _lastRouteOrigin;
  double? _routeDistanceMeters;
  int? _routeTimeSeconds;

  LatLng? get _driverLocation {
    final position = widget.store.position;
    return position == null
        ? null
        : LatLng(position.latitude, position.longitude);
  }

  bool get _isHeadingToRestaurant =>
      widget.order.stage.index < DeliveryStage.pickedUp.index;

  LatLng? get _destination {
    final order = widget.order;
    final lat = _isHeadingToRestaurant
        ? order.pickupLatitude
        : order.dropoffLatitude;
    final lng = _isHeadingToRestaurant
        ? order.pickupLongitude
        : order.dropoffLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_locationChanged);
    if (_routeKey.isNotEmpty) {
      vietmap.Vietmap.getInstance(_routeKey);
    }
  }

  @override
  void didUpdateWidget(covariant DeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_locationChanged);
      widget.store.addListener(_locationChanged);
    }
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.stage != widget.order.stage) {
      _lastRouteOrigin = null;
      _routeDistanceMeters = null;
      _routeTimeSeconds = null;
      unawaited(_loadRoute());
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_locationChanged);
    widget.store.updateRouteDistance(null);
    super.dispose();
  }

  void _locationChanged() {
    if (!mounted) return;
    final origin = _driverLocation;
    if (origin != null && _shouldRefreshRoute(origin)) {
      unawaited(_loadRoute());
    }
    if (_following && origin != null) {
      unawaited(_map?.animateCamera(CameraUpdate.newLatLng(origin)));
    }
  }

  bool _shouldRefreshRoute(LatLng origin) {
    final previous = _lastRouteOrigin;
    if (previous == null) return true;
    return _distanceMeters(previous, origin) >= 15;
  }

  double _distanceMeters(LatLng a, LatLng b) {
    final lat = (a.latitude - b.latitude) * 111000;
    final lng = (a.longitude - b.longitude) * 111000;
    return math.sqrt(lat * lat + lng * lng);
  }

  Future<void> _loadRoute() async {
    final origin = _driverLocation;
    final destination = _destination;
    if (origin == null || destination == null) {
      widget.store.updateRouteDistance(null);
      return;
    }
    if (_routeLoading) return;

    final straightLineMeters = _distanceMeters(origin, destination);
    if (straightLineMeters < 25) {
      _lastRouteOrigin = origin;
      if (mounted) {
        setState(() {
          _route = [origin, destination];
          _routeDistanceMeters = straightLineMeters;
          _routeTimeSeconds = 0;
          _routeUnavailable = false;
        });
      }
      widget.store.updateRouteDistance(straightLineMeters);
      unawaited(_drawRoutePolyline());
      return;
    }

    if (_routeKey.isEmpty) {
      if (mounted) {
        setState(() {
          _routeUnavailable = true;
          _routeDistanceMeters = straightLineMeters;
        });
      }
      widget.store.updateRouteDistance(straightLineMeters);
      return;
    }
    _routeLoading = true;
    try {
      final result = await vietmap.Vietmap.routing(
        vietmap.VietMapRoutingParams(
          points: [
            vietmap.LatLng(origin.latitude, origin.longitude),
            vietmap.LatLng(destination.latitude, destination.longitude),
          ],
          vehicle: vietmap.VehicleType.motorcycle,
        ),
      );
      result.fold(
        (_) {
          if (mounted) {
            setState(() {
              _routeUnavailable = true;
              _routeDistanceMeters = straightLineMeters;
            });
          }
          widget.store.updateRouteDistance(straightLineMeters);
        },
        (route) {
          final path = route.paths?.firstOrNull;
          final points = path?.pointsLatLng;
          if (points == null || !mounted) {
            widget.store.updateRouteDistance(straightLineMeters);
            return;
          }
          _lastRouteOrigin = origin;
          setState(() {
            _route = points;
            _routeDistanceMeters = path?.distance?.toDouble() ?? straightLineMeters;
            _routeTimeSeconds = path?.time != null
                ? (path!.time! / 1000).round()
                : null;
            _routeUnavailable = false;
          });
          widget.store.updateRouteDistance(_routeDistanceMeters);
          unawaited(_drawRoutePolyline());
          _fitRouteBounds(points);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _routeUnavailable = true;
          _routeDistanceMeters = straightLineMeters;
        });
      }
      widget.store.updateRouteDistance(straightLineMeters);
    } finally {
      _routeLoading = false;
    }
  }

  Future<void> _drawRoutePolyline() async {
    final map = _map;
    if (!_styleLoaded || map == null || map.isDisposed) return;
    try {
      if (_lines.isNotEmpty) {
        await map.removePolylines(_lines);
        _lines = [];
      }
      if (_route.length > 1) {
        final line = await map.addPolyline(
          PolylineOptions(
            geometry: _route,
            polylineColor: AppColors.primary,
            polylineWidth: 6,
            polylineOpacity: .9,
          ),
        );
        _lines = [line];
      }
    } catch (_) {
      // Polyline render failure handled gracefully
    }
  }

  void _fitRouteBounds(List<LatLng> points) {
    final map = _map;
    if (map == null || points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    if ((maxLat - minLat).abs() < 0.003 && (maxLng - minLng).abs() < 0.003) {
      unawaited(
        map.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
            15.5,
          ),
        ),
      );
      return;
    }

    unawaited(
      map.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: 40,
          top: 80,
          right: 40,
          bottom: 40,
        ),
      ),
    );
  }

  void _onMapCreated(VietmapController controller) {
    _map = controller;
    if (mounted) setState(() {});
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    unawaited(_drawRoutePolyline());
    unawaited(_loadRoute());
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final driver = _driverLocation;
    final order = widget.order;

    // Driver Marker
    if (driver != null) {
      markers.add(
        Marker(
          latLng: driver,
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .35),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bike_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
    }

    // Restaurant Marker
    if (order.pickupLatitude != null && order.pickupLongitude != null) {
      markers.add(
        Marker(
          latLng: LatLng(order.pickupLatitude!, order.pickupLongitude!),
          width: 130,
          height: 52,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: Text(
                  order.restaurant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.storefront_rounded,
                color: Color(0xFFD32F2F),
                size: 28,
              ),
            ],
          ),
        ),
      );
    }

    // Customer / Dropoff Marker
    if (order.dropoffLatitude != null && order.dropoffLongitude != null) {
      markers.add(
        Marker(
          latLng: LatLng(order.dropoffLatitude!, order.dropoffLongitude!),
          width: 130,
          height: 52,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: Text(
                  order.customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ),
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.green,
                size: 30,
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final driver = _driverLocation;
    final destination = _destination;

    if (_tileKey.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFEEF4F6),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Thiếu cấu hình Vietmap Tilemap key\nVui lòng thêm --dart-define=VIETMAP_TILEMAP_KEY=...',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final center = driver ?? destination ?? const LatLng(10.7626, 106.6823);
    final style =
        'https://maps.vietmap.vn/maps/styles/tm/style.json?apikey=$_tileKey';

    return Stack(
      fit: StackFit.expand,
      children: [
        VietmapGL(
          key: ValueKey(widget.order.id),
          styleString: style,
          initialCameraPosition: CameraPosition(target: center, zoom: 15),
          trackCameraPosition: true,
          compassEnabled: true,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
        ),
        if (_map != null)
          MarkerLayer(
            mapController: _map!,
            markers: _buildMarkers(),
          ),
        // Route Info Banner (Top Left)
        if (_route.isNotEmpty || _routeDistanceMeters != null)
          Positioned(
            top: 12,
            left: 12,
            right: 70, // Avoid overlapping with refresh/gps FABs on top right
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      _isHeadingToRestaurant
                          ? Icons.storefront
                          : Icons.location_on,
                      color: _isHeadingToRestaurant
                          ? AppColors.primary
                          : AppColors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isHeadingToRestaurant
                                ? 'Đến quán: ${widget.order.restaurant}'
                                : 'Giao khách: ${widget.order.customer}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          if (_routeDistanceMeters != null)
                            Text(
                              '${(_routeDistanceMeters! / 1000).toStringAsFixed(1)} km'
                              '${_routeTimeSeconds != null ? ' • ~${math.max(1, (_routeTimeSeconds! / 60).round())} phút' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
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
        // Attribution / Status Banner (Bottom Left)
        Positioned(
          left: 12,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                _routeUnavailable
                    ? 'Không tải được tuyến • © Vietmap'
                    : '© Vietmap',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ),
        ),
        // Follow / Recenter FAB (Bottom Right)
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'delivery-map-follow',
            tooltip: _following ? 'Đang theo dõi vị trí' : 'Định vị lại',
            backgroundColor: Colors.white,
            foregroundColor: _following ? AppColors.primary : AppColors.ink,
            onPressed: driver == null
                ? null
                : () {
                    setState(() => _following = !_following);
                    unawaited(
                      _map?.animateCamera(CameraUpdate.newLatLng(driver)),
                    );
                  },
            child: Icon(_following ? Icons.navigation : Icons.my_location),
          ),
        ),
      ],
    );
  }
}
