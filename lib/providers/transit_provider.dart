import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/stop.dart';
import '../models/vehicle_position.dart';
import '../services/database_service.dart';
import '../services/gtfs_realtime_service.dart';
import '../services/gtfs_static_service.dart';

enum LoadStatus {
  initial,
  loading,
  ready,
  error,
}

class TransitProvider extends ChangeNotifier with WidgetsBindingObserver {
  final GtfsStaticService _staticService = GtfsStaticService();
  final GtfsStaticService _railStaticService = GtfsStaticService(
    staticUrl:
        'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl',
  );
  final GtfsRealtimeService _realtimeService = GtfsRealtimeService();
  final DatabaseService _db = DatabaseService.instance;

  List<Stop> _stops = [];
  List<TransitRoute> _routes = [];
  List<TransitRoute> _railRoutes = [];
  Future<void>? _railRouteLoad;
  List<VehiclePosition> _vehicles = [];
  DateTime? _vehiclesUpdatedAt;
  bool _showingLastKnownVehicles = false;

  LoadStatus _stopsStatus = LoadStatus.initial;
  LoadStatus _vehiclesStatus = LoadStatus.initial;

  String? _errorMessage;

  Timer? _pollTimer;

  bool _isRefreshingVehicles = false;
  DateTime? _lastVehicleRefresh;

  TransitProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  List<Stop> get stops => _stops;

  List<TransitRoute> get routes => _routes;

  List<VehiclePosition> get vehicles => _vehicles;

  DateTime? get vehiclesUpdatedAt => _vehiclesUpdatedAt;

  bool get showingLastKnownVehicles => _showingLastKnownVehicles;

  String displayRouteLabel(String? routeId) {
    return mappedPassengerRouteLabel(routeId) ?? routeId ?? 'Unknown';
  }

  String? mappedPassengerRouteLabel(String? routeCode) {
    if (routeCode == null || routeCode.isEmpty) return null;
    for (final route in [..._routes, ..._railRoutes]) {
      if (route.routeId == routeCode || route.shortName == routeCode) {
        return route.passengerDisplayLabel;
      }
    }
    return null;
  }

  LoadStatus get stopsStatus => _stopsStatus;

  LoadStatus get vehiclesStatus => _vehiclesStatus;

  String? get errorMessage => _errorMessage;

  Future<void> initialise() async {
    debugPrint(
      'TransitProvider initialise started',
    );

    await Future.wait([
      loadStopsAndRoutes(),
      loadRailRouteLabels(),
      refreshVehicles(),
    ]);

    debugPrint(
      'Stops loaded: ${_stops.length}',
    );

    debugPrint(
      'Routes loaded: ${_routes.length}',
    );

    startPolling();

    debugPrint(
      'TransitProvider initialise completed',
    );
  }

  Future<void> loadStopsAndRoutes({
    bool forceRefresh = false,
  }) async {
    _stopsStatus = LoadStatus.loading;

    notifyListeners();

    try {
      if (!forceRefresh) {
        final cachedStops = await _db.getAllStops();

        if (cachedStops.isNotEmpty) {
          _stops = cachedStops;
          _routes = await _db.getAllRoutes();

          _stopsStatus = LoadStatus.ready;
          notifyListeners();

          debugPrint(
            'Showing ${_stops.length} cached stops '
            'while checking for a refresh.',
          );
        }
      }

      final needsRefresh = forceRefresh || await _db.shouldRefreshStops();

      debugPrint(
        'GTFS static refresh required: $needsRefresh',
      );

      if (needsRefresh || _stops.isEmpty) {
        _staticService.clearCache();

        final freshStops = await _staticService.fetchStops();

        final freshRoutes = await _staticService.fetchRoutes();

        await _db.replaceStops(
          freshStops,
          category: AppConstants.gtfsCategory,
        );

        await _db.replaceRoutes(
          freshRoutes,
        );

        _stops = freshStops;
        _routes = freshRoutes;
      }

      _stopsStatus = LoadStatus.ready;
      _errorMessage = null;

      debugPrint(
        'Stops successfully loaded: '
        '${_stops.length}',
      );

      debugPrint(
        'Routes successfully loaded: '
        '${_routes.length}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'GTFS static error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      _errorMessage = 'Could not load stops: $e';

      _stopsStatus = LoadStatus.error;

      try {
        _stops = await _db.getAllStops();

        _routes = await _db.getAllRoutes();
      } catch (dbError) {
        debugPrint(
          'Database fallback error: '
          '$dbError',
        );
      }
    }

    notifyListeners();
  }

  Future<void> loadRailRouteLabels() async {
    if (_railRoutes.isNotEmpty) return;
    _railRouteLoad ??= _loadRailRouteLabels();
    await _railRouteLoad;
  }

  Future<void> _loadRailRouteLabels() async {
    try {
      _railRoutes = await _railStaticService.fetchRoutes();
    } catch (error) {
      debugPrint('Could not load Rapid Rail route labels: $error');
    }
  }

  Future<void> refreshVehicles() async {
    final lastRefresh = _lastVehicleRefresh;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < const Duration(seconds: 10)) {
      debugPrint(
        'Vehicle refresh skipped: recently refreshed.',
      );

      return;
    }

    if (_isRefreshingVehicles) {
      debugPrint(
        'Vehicle refresh skipped: '
        'another request is still running.',
      );

      return;
    }

    _isRefreshingVehicles = true;

    try {
      _vehiclesStatus = LoadStatus.loading;

      notifyListeners();

      debugPrint(
        '================================',
      );

      debugPrint(
        'Refreshing live buses...',
      );

      final vehicles = await _realtimeService.fetchVehiclePositions();
      _lastVehicleRefresh = DateTime.now();

      if (vehicles.isEmpty && _vehicles.isNotEmpty) {
        _showingLastKnownVehicles = true;
      } else {
        _vehicles = vehicles;
        _vehiclesUpdatedAt = vehicles.isEmpty ? null : _lastVehicleRefresh;
        _showingLastKnownVehicles = false;
      }

      debugPrint(
        'TransitProvider received '
        '${_vehicles.length} live buses',
      );

      for (final vehicle in _vehicles.take(5)) {
        debugPrint(
          'Bus ${vehicle.vehicleId}: '
          '${vehicle.lat}, '
          '${vehicle.lng} '
          'route=${vehicle.routeId} '
          'trip=${vehicle.tripId}',
        );
      }

      if (vehicles.isEmpty) {
        debugPrint(
          'WARNING: GTFS API returned '
          '0 usable vehicles.',
        );

        _errorMessage = _vehicles.isEmpty
            ? 'Realtime is online, but no buses are being reported right now.'
            : 'Realtime is online, but the latest feed is empty. '
                'Showing last known bus positions.';
      } else {
        _errorMessage = null;
      }

      _vehiclesStatus = LoadStatus.ready;
    } catch (e, stackTrace) {
      debugPrint(
        'Live bus error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      _vehiclesStatus = _vehicles.isEmpty ? LoadStatus.error : LoadStatus.ready;

      _errorMessage = 'Live tracking temporarily unavailable: $e';
    } finally {
      _isRefreshingVehicles = false;
    }

    notifyListeners();
  }

  void startPolling() {
    _pollTimer?.cancel();

    debugPrint(
      'Starting realtime bus polling '
      'every '
      '${AppConstants.realtimePollInterval.inSeconds} '
      'seconds',
    );

    _pollTimer = Timer.periodic(
      AppConstants.realtimePollInterval,
      (_) {
        refreshVehicles();
      },
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshVehicles();
      startPolling();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      stopPolling();
    }
  }

  List<Stop> searchStopsLocally(
    String query,
  ) {
    if (query.trim().isEmpty) {
      return [];
    }

    final q = _normaliseStopSearchText(query);
    final matches = _stops
        .where(
          (stop) => _normaliseStopSearchText(stop.name).contains(q),
        )
        .toList();

    if (matches.isNotEmpty) return matches;

    final words = query.trim().split(RegExp(r'\s+'));
    if (words.length > 1 && words.last.length <= 3) {
      final completedQuery = _normaliseStopSearchText(
        words.sublist(0, words.length - 1).join(' '),
      );
      return _stops
          .where(
            (stop) => _normaliseStopSearchText(stop.name)
                .contains(completedQuery),
          )
          .toList();
    }

    return matches;
  }

  String _normaliseStopSearchText(String value) {
    var normalised = value.toLowerCase().trim();
    normalised = normalised.replaceAll('pintu', 'gate');
    normalised = normalised.replaceAll('main', '');
    return normalised.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<VehiclePosition> vehiclesNearStop(
    Stop stop, {
    double radiusKm = 1.0,
  }) {
    const Distance distance = Distance();

    final stopLocation = LatLng(
      stop.lat,
      stop.lng,
    );

    final nearbyVehicles = _vehicles.where(
      (vehicle) {
        final vehicleLocation = LatLng(
          vehicle.lat,
          vehicle.lng,
        );

        final distanceInMeters = distance.as(
          LengthUnit.Meter,
          stopLocation,
          vehicleLocation,
        );

        return distanceInMeters <= radiusKm * 1000;
      },
    ).toList();

    nearbyVehicles.sort(
      (a, b) {
        final distanceA = distance.as(
          LengthUnit.Meter,
          stopLocation,
          LatLng(
            a.lat,
            a.lng,
          ),
        );

        final distanceB = distance.as(
          LengthUnit.Meter,
          stopLocation,
          LatLng(
            b.lat,
            b.lng,
          ),
        );

        return distanceA.compareTo(
          distanceB,
        );
      },
    );

    debugPrint(
      'Found ${nearbyVehicles.length} '
      'live buses within $radiusKm km '
      'of ${stop.name}',
    );

    return nearbyVehicles;
  }

  double distanceToVehicle(
    Stop stop,
    VehiclePosition vehicle,
  ) {
    const Distance distance = Distance();

    return distance.as(
      LengthUnit.Meter,
      LatLng(
        stop.lat,
        stop.lng,
      ),
      LatLng(
        vehicle.lat,
        vehicle.lng,
      ),
    );
  }

  VehiclePosition? findVehicleById(
    String vehicleId,
  ) {
    for (final vehicle in _vehicles) {
      if (vehicle.vehicleId == vehicleId) {
        return vehicle;
      }
    }

    return null;
  }

  Future<List<LatLng>> getRouteShapeForVehicle(
    VehiclePosition vehicle,
  ) async {
    final tripId = vehicle.tripId;

    if (tripId == null || tripId.isEmpty) {
      debugPrint(
        'Cannot load route shape: '
        'bus ${vehicle.vehicleId} '
        'has no tripId.',
      );

      return [];
    }

    try {
      debugPrint(
        '================================',
      );

      debugPrint(
        'Loading actual GTFS route...',
      );

      debugPrint(
        'Bus ID: ${vehicle.vehicleId}',
      );

      debugPrint(
        'Route ID: ${vehicle.routeId}',
      );

      debugPrint(
        'Trip ID: $tripId',
      );

      final shapeId = await _staticService.findShapeIdForTrip(
        tripId,
      );

      if (shapeId == null || shapeId.isEmpty) {
        debugPrint(
          'No shape ID found '
          'for trip $tripId',
        );

        return [];
      }

      debugPrint(
        'Shape ID: $shapeId',
      );

      final shapePoints = await _staticService.fetchShapeForId(
        shapeId,
      );

      if (shapePoints.isEmpty) {
        debugPrint(
          'No shape points found '
          'for shape $shapeId',
        );

        return [];
      }

      final routePoints = shapePoints.map(
        (point) {
          return LatLng(
            point.lat,
            point.lng,
          );
        },
      ).toList();

      debugPrint(
        'Loaded '
        '${routePoints.length} '
        'route points.',
      );

      debugPrint(
        'Route successfully loaded '
        'for ${vehicle.vehicleId}',
      );

      debugPrint(
        '================================',
      );

      return routePoints;
    } catch (e, stackTrace) {
      debugPrint(
        'Failed to load GTFS route: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      return [];
    }
  }

  Future<Set<String>> routeIdsForStop(Stop stop) =>
      _staticService.findRouteIdsForStop(stop.stopId);

  Future<List<String>> stopIdsForRoute(String routeId) =>
      _staticService.findStopIdsForRoute(routeId);

  Future<List<LatLng>> getRouteShapeForStop(Stop stop) async {
    try {
      final tripId = await _staticService.findTripIdForStop(stop.stopId);
      if (tripId == null || tripId.isEmpty) {
        return [];
      }

      final shapeId = await _staticService.findShapeIdForTrip(tripId);
      if (shapeId == null || shapeId.isEmpty) {
        return [];
      }

      final shapePoints = await _staticService.fetchShapeForId(shapeId);
      return shapePoints.map((point) => LatLng(point.lat, point.lng)).toList();
    } catch (error) {
      debugPrint('Failed to load GTFS route for ${stop.stopId}: $error');
      return [];
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();

    super.dispose();
  }
}
