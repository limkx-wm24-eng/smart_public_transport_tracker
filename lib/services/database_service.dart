import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/favourite_route.dart';
import '../models/route_model.dart';
import '../models/stop.dart';

/// Single source of truth for local (on-device) storage.
///
/// Uses `shared_preferences` rather than `sqflite` — sqflite only works on
/// Android/iOS/desktop, not Flutter Web, and this app needs to run on web
/// for quick UI testing as well as mobile. shared_preferences works
/// everywhere, at the cost of being a simple key-value store rather than
/// a real relational database: we store each collection (stops, routes,
/// favourites) as one JSON-encoded string under a single key.
///
/// This is a deliberate trade-off worth noting in your report: fine for a
/// dataset of a few thousand stops/routes, but a real production app at
/// larger scale would want sqflite (mobile) + IndexedDB (web) instead,
/// each behind a shared interface, so lookups don't require decoding the
/// entire collection every time.
///
/// Keys used:
///  - `stops_cache`         : JSON list of cached GTFS-Static stops
///  - `stops_last_synced`   : ISO8601 timestamp of the last stops refresh
///  - `routes_cache`        : JSON list of cached GTFS-Static routes
///  - `favourite_routes`    : JSON list of the user's saved bus lines
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsInstance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ------------------------------------------------------------------
  // Stops cache (populated from GTFS-Static)
  // ------------------------------------------------------------------

  Future<void> replaceStops(List<Stop> stops) async {
    final prefs = await _prefsInstance;
    final jsonList = stops.map((s) => s.toMap()).toList();
    await prefs.setString('stops_cache', jsonEncode(jsonList));
    await prefs.setString(
        'stops_last_synced', DateTime.now().toIso8601String());
  }

  Future<List<Stop>> getAllStops() async {
    final prefs = await _prefsInstance;
    final raw = prefs.getString('stops_cache');
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => Stop.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> shouldRefreshStops() async {
    final prefs = await _prefsInstance;
    final lastSyncedStr = prefs.getString('stops_last_synced');
    if (lastSyncedStr == null) return true;
    final lastSynced = DateTime.tryParse(lastSyncedStr);
    if (lastSynced == null) return true;
    return DateTime.now().difference(lastSynced) >
        AppConstants.staticDataMaxAge;
  }

  // ------------------------------------------------------------------
  // Routes cache (populated from GTFS-Static, used to label ETAs with
  // human-readable bus numbers instead of raw route_id)
  // ------------------------------------------------------------------

  Future<void> replaceRoutes(List<TransitRoute> routes) async {
    final prefs = await _prefsInstance;
    final jsonList = routes.map((r) => r.toMap()).toList();
    await prefs.setString('routes_cache', jsonEncode(jsonList));
  }

  Future<List<TransitRoute>> getAllRoutes() async {
    final prefs = await _prefsInstance;
    final raw = prefs.getString('routes_cache');
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => TransitRoute.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ------------------------------------------------------------------
  // Favourite routes (bus lines) — the app's primary favourites feature
  // ------------------------------------------------------------------

  Future<void> addFavouriteRoute(FavouriteRoute fav) async {
    final favs = await getFavouriteRoutes();
    favs.removeWhere((f) => f.routeId == fav.routeId);
    favs.insert(0, fav);
    await _saveFavouriteRoutes(favs);
  }

  Future<void> removeFavouriteRoute(String routeId) async {
    final favs = await getFavouriteRoutes();
    favs.removeWhere((f) => f.routeId == routeId);
    await _saveFavouriteRoutes(favs);
  }

  Future<List<FavouriteRoute>> getFavouriteRoutes() async {
    final prefs = await _prefsInstance;
    final raw = prefs.getString('favourite_routes');
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map(
            (e) => FavouriteRoute.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> isFavouriteRoute(String routeId) async {
    final favs = await getFavouriteRoutes();
    return favs.any((f) => f.routeId == routeId);
  }

  Future<void> _saveFavouriteRoutes(List<FavouriteRoute> favs) async {
    final prefs = await _prefsInstance;
    final jsonList = favs.map((f) => f.toMap()).toList();
    await prefs.setString('favourite_routes', jsonEncode(jsonList));
  }
}