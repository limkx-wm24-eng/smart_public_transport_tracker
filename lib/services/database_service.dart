import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/favourite_stop.dart';
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
///  - `favourites`          : JSON list of the user's saved stops
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
  // Routes cache (populated from GTFS-Static, used to label live buses
  // with human-readable bus numbers instead of raw route_id)
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
  // Favourite stops — the app's favourites feature
  // ------------------------------------------------------------------

  Future<void> addFavourite(FavouriteStop fav) async {
    final favs = await getFavourites();
    favs.removeWhere((f) => f.stopId == fav.stopId);
    favs.insert(0, fav);
    await _saveFavourites(favs);
  }

  Future<void> removeFavourite(String stopId) async {
    final favs = await getFavourites();
    favs.removeWhere((f) => f.stopId == stopId);
    await _saveFavourites(favs);
  }

  Future<List<FavouriteStop>> getFavourites() async {
    final prefs = await _prefsInstance;
    final raw = prefs.getString('favourites');
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => FavouriteStop.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> isFavourite(String stopId) async {
    final favs = await getFavourites();
    return favs.any((f) => f.stopId == stopId);
  }

  Future<void> _saveFavourites(List<FavouriteStop> favs) async {
    final prefs = await _prefsInstance;
    final jsonList = favs.map((f) => f.toMap()).toList();
    await prefs.setString('favourites', jsonEncode(jsonList));
  }
}