import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favourite_stop.dart';
import '../models/stop.dart';
import '../services/database_service.dart';
import '../services/supabase_favourites_service.dart';

/// Manages the user's saved (favourite) stops using SQLite AND Supabase
/// together, scoped by the logged-in user's id:
///
///  - SQLite (DatabaseService)             : local cache — instant reads,
///                                            works offline
///  - Supabase (SupabaseFavouritesService) : remote source of truth,
///                                            scoped to auth.uid() via RLS
///
/// Requires the user to be logged in — load() and toggleFavourite() are
/// no-ops if nobody is signed in.
class FavouritesProvider extends ChangeNotifier {
  final DatabaseService _localDb = DatabaseService.instance;
  final SupabaseFavouritesService _remote = SupabaseFavouritesService();

  List<FavouriteStop> _favourites = [];
  List<FavouriteStop> get favourites => _favourites;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final remoteFavs = await _remote.fetchFavourites(userId);
      _favourites = remoteFavs;
      _isOffline = false;
      await _localDb.cacheFavourites(remoteFavs);
    } catch (e) {
      debugPrint('Supabase unreachable, falling back to local cache: $e');
      _isOffline = true;
      _favourites = await _localDb.getCachedFavourites();
    }

    notifyListeners();
  }

  bool isFavourite(String stopId) {
    return _favourites.any((f) => f.stopId == stopId);
  }

  Future<void> toggleFavourite(Stop stop) async {
    final userId = _userId;
    if (userId == null) return;

    if (isFavourite(stop.stopId)) {
      _favourites.removeWhere((f) => f.stopId == stop.stopId);
      notifyListeners();
      await _localDb.cacheRemoveFavourite(stop.stopId);
      try {
        await _remote.removeFavourite(userId, stop.stopId);
      } catch (e) {
        debugPrint('Could not sync removal to Supabase: $e');
      }
    } else {
      final fav = FavouriteStop(
        stopId: stop.stopId,
        name: stop.name,
        lat: stop.lat,
        lng: stop.lng,
        savedAt: DateTime.now(),
      );
      _favourites.insert(0, fav);
      notifyListeners();
      await _localDb.cacheAddFavourite(fav);
      try {
        await _remote.addFavourite(userId, fav);
      } catch (e) {
        debugPrint('Could not sync addition to Supabase: $e');
      }
    }
  }

  /// Clears favourites from memory (not from SQLite/Supabase) on sign out,
  /// so the next person who logs in on this device doesn't briefly see the
  /// previous user's list before load() runs.
  void clearOnSignOut() {
    _favourites = [];
    notifyListeners();
  }
}