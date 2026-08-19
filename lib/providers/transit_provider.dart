import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/stop.dart';
import '../models/vehicle_eta.dart';
import '../models/vehicle_position.dart';
import '../services/database_service.dart';
import '../services/eta_service.dart';
import '../services/gtfs_realtime_service.dart';
import '../services/gtfs_static_service.dart';

/// Member A's module — live map + tracking.
///
/// Owns:
///  - the cached list of stops (loaded from SQLite, refreshed from
///    GTFS-Static when stale)
///  - the currently-polled list of live vehicle positions
enum LoadStatus { initial, loading, ready, error }

class TransitProvider extends ChangeNotifier {
  final GtfsStaticService _staticService = GtfsStaticService();
  final GtfsRealtimeService _realtimeService = GtfsRealtimeService();
  final DatabaseService _db = DatabaseService.instance;
  final EtaService _etaService = EtaService();

  List<Stop> _stops = [];
  List<TransitRoute> _routes = [];
  List<VehiclePosition> _vehicles = [];
  LoadStatus _stopsStatus = LoadStatus.initial;
  LoadStatus _vehiclesStatus = LoadStatus.initial;
  String? _errorMessage;
  Timer? _pollTimer;

  List<Stop> get stops => _stops;
  List<TransitRoute> get routes => _routes;
  List<VehiclePosition> get vehicles => _vehicles;
  LoadStatus get stopsStatus => _stopsStatus;
  LoadStatus get vehiclesStatus => _vehiclesStatus;
  String? get errorMessage => _errorMessage;

  /// Call once when the app starts (e.g. from the splash screen).
  Future<void> initialise() async {
    await loadStopsAndRoutes();
    await refreshVehicles();
    startPolling();
  }

  Future<void> loadStopsAndRoutes({bool forceRefresh = false}) async {
    _stopsStatus = LoadStatus.loading;
    notifyListeners();

    try {
      final needsRefresh = forceRefresh || await _db.shouldRefreshStops();
      if (needsRefresh) {
        _staticService.clearCache();
        final freshStops = await _staticService.fetchStops();
        final freshRoutes = await _staticService.fetchRoutes();
        await _db.replaceStops(freshStops);
        await _db.replaceRoutes(freshRoutes);
        _stops = freshStops;
        _routes = freshRoutes;
      } else {
        _stops = await _db.getAllStops();
        _routes = await _db.getAllRoutes();
        // Fallback: if the cache is somehow empty, fetch anyway.
        if (_stops.isEmpty) {
          _stops = await _staticService.fetchStops();
          _routes = await _staticService.fetchRoutes();
          await _db.replaceStops(_stops);
          await _db.replaceRoutes(_routes);
        }
      }
      _stopsStatus = LoadStatus.ready;
    } catch (e) {
      _errorMessage = 'Could not load stops: $e';
      _stopsStatus = LoadStatus.error;
      // Fall back to whatever is cached, even if stale.
      _stops = await _db.getAllStops();
      _routes = await _db.getAllRoutes();
    }
    notifyListeners();
  }

  /// ETA list for a given stop, recomputed live from the current vehicle
  /// positions — see EtaService for how the estimate is derived.
  List<VehicleEta> etasForStop(Stop stop) {
    return _etaService.estimateForStop(
      stop: stop,
      vehicles: _vehicles,
      routes: _routes,
    );
  }

  Future<void> refreshVehicles() async {
    try {
      _vehicles = await _realtimeService.fetchVehiclePositions();
      _vehiclesStatus = LoadStatus.ready;
      _errorMessage = null;
    } catch (e) {
      // Don't wipe existing markers on a transient failure — keep showing
      // the last known positions rather than an empty map.
      _vehiclesStatus =
          _vehicles.isEmpty ? LoadStatus.error : LoadStatus.ready;
      _errorMessage = 'Live tracking temporarily unavailable: $e';
    }
    notifyListeners();
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      AppConstants.realtimePollInterval,
      (_) => refreshVehicles(),
    );
  }

  List<Stop> searchStopsLocally(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return _stops.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
