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

/// Member A's module — live map + tracking.
///
/// Owns:
/// - cached GTFS stops and routes
/// - currently-polled live vehicle positions
/// - nearby bus searching
/// - actual GTFS route shape loading
enum LoadStatus {
  initial,
  loading,
  ready,
  error,
}

class TransitProvider extends ChangeNotifier with WidgetsBindingObserver {
  final GtfsStaticService _staticService = GtfsStaticService();
  final GtfsStaticService _railStaticService = GtfsStaticService(
    staticUrl: 'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl',
  );
  final GtfsRealtimeService _realtimeService = GtfsRealtimeService();
  final DatabaseService _db = DatabaseService.instance;

  List<Stop> _stops = [];
  List<TransitRoute> _routes = [];
  List<TransitRoute> _railRoutes = [];
  Future<void>? _railRouteLoad;
  List<VehiclePosition> _vehicles = [];

  LoadStatus _stopsStatus = LoadStatus.initial;
  LoadStatus _vehiclesStatus = LoadStatus.initial;

  String? _errorMessage;

  Timer? _pollTimer;

  bool _isRefreshingVehicles = false;
  DateTime? _lastVehicleRefresh;

  TransitProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ============================================================
  // GETTERS
  // ============================================================

  List<Stop> get stops => _stops;

  List<TransitRoute> get routes => _routes;

  List<VehiclePosition> get vehicles => _vehicles;

  /// Converts the GTFS-Realtime internal route_id into the passenger-facing
  /// route_short_name from GTFS Static routes.txt. Realtime matching still
  /// uses the original ID; this is only for display.
  String displayRouteLabel(String? routeId) {
    return mappedPassengerRouteLabel(routeId) ?? routeId ?? 'Unknown';
  }

  /// Resolves either a GTFS route_id or a public short code. The rail feed is
  /// loaded separately because Google transit suggestions can combine buses
  /// with LRT/MRT lines even when this app's live feed is bus-only.
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

  // ============================================================
  // INITIALISE
  // ============================================================

  Future<void> initialise() async {
    debugPrint(
      'TransitProvider initialise started',
    );

    // Stops/routes and live vehicle positions are independent of each
    // other, so there's no reason to wait for one before starting the
    // other — running them in parallel roughly halves the time spent on
    // the splash screen compared to doing them one after another.
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

  // ============================================================
  // LOAD GTFS STATIC STOPS + ROUTES
  // ============================================================

  Future<void> loadStopsAndRoutes({
    bool forceRefresh = false,
  }) async {
    _stopsStatus = LoadStatus.loading;

    notifyListeners();

    try {
      // Show whatever's already cached locally right away, so the UI
      // isn't blocked on a network round-trip just to display stops the
      // device already has. If the cache turns out to be stale, we
      // refresh it below — the user sees data instantly either way.
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

  // ============================================================
  // REFRESH LIVE BUS POSITIONS
  // ============================================================

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

      _vehicles = vehicles;
      _lastVehicleRefresh = DateTime.now();

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

      if (_vehicles.isEmpty) {
        debugPrint(
          'WARNING: GTFS API returned '
          '0 usable vehicles.',
        );

        _errorMessage = 'Realtime service is online, '
            'but no buses are currently being reported.';
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

  // ============================================================
  // AUTO REFRESH LIVE BUSES
  // ============================================================

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

  // ============================================================
  // STOP SEARCH
  // ============================================================

  List<Stop> searchStopsLocally(
    String query,
  ) {
    if (query.trim().isEmpty) {
      return [];
    }

    final q = query.trim().toLowerCase();

    return _stops
        .where(
          (stop) => stop.name.toLowerCase().contains(q),
        )
        .toList();
  }

  // ============================================================
  // FIND LIVE BUSES NEAR A STOP
  // ============================================================

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

  // ============================================================
  // CALCULATE DISTANCE BETWEEN STOP AND BUS
  // ============================================================

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

  // ============================================================
  // FIND LATEST VERSION OF A BUS
  // ============================================================

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

  // ============================================================
  // GET ACTUAL GTFS ROUTE SHAPE FOR A LIVE BUS
  // ============================================================

  Future<List<LatLng>> getRouteShapeForVehicle(
    VehiclePosition vehicle,
  ) async {
    final tripId = vehicle.tripId;

    // We need tripId to determine the correct GTFS shape.
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

      // --------------------------------------------------------
      // STEP 1:
      // trip_id -> shape_id
      // --------------------------------------------------------

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

      // --------------------------------------------------------
      // STEP 2:
      // shape_id -> route coordinates
      // --------------------------------------------------------

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

      // --------------------------------------------------------
      // STEP 3:
      // Convert ShapePoint -> LatLng
      // --------------------------------------------------------

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

  /// GTFS-static route IDs serving a stop, used by the journey assistant.
  Future<Set<String>> routeIdsForStop(Stop stop) =>
      _staticService.findRouteIdsForStop(stop.stopId);

  /// GTFS-static stop IDs served by a route, used by planner fallback search.
  Future<List<String>> stopIdsForRoute(String routeId) =>
      _staticService.findStopIdsForRoute(routeId);

  /// Loads one GTFS route shape that serves [stop]. This provides a route
  /// preview even when no live vehicle is currently within the nearby range.
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

  // ============================================================
  // CLEAN UP TIMER
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();

    super.dispose();
  }
}
