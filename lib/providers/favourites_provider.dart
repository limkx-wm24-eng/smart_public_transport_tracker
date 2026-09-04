import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favourite_stop.dart';
import '../models/stop.dart';
import '../services/database_service.dart';
import '../services/supabase_favourites_service.dart';



class FavouritesProvider extends ChangeNotifier {
  final DatabaseService _localDb = DatabaseService.instance;
  final SupabaseFavouritesService _remote = SupabaseFavouritesService();

  List<FavouriteStop> _favourites = [];
  bool _isOffline = false;

  List<FavouriteStop> get favourites => List.unmodifiable(_favourites);
  bool get isOffline => _isOffline;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool isFavourite(String stopId) {
    return _favourites.any((favourite) => favourite.stopId == stopId);
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      _favourites = [];
      _isOffline = false;
      notifyListeners();
      return;
    }

    try {
      final remoteFavourites = await _remote.fetchFavourites(userId);
      _favourites = remoteFavourites;
      _isOffline = false;
      await _localDb.cacheFavourites(remoteFavourites);
    } catch (error) {
      debugPrint('Supabase unreachable, falling back to local cache: $error');
      _isOffline = true;
      try {
        _favourites = await _localDb.getCachedFavourites();
      } catch (cacheError) {
        debugPrint('Could not load cached favourites: $cacheError');
        _favourites = [];
      }
    }

    notifyListeners();
  }


  Future<void> loadFavourites() => load();

  Future<void> toggleFavourite(Stop stop) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    if (isFavourite(stop.stopId)) {
      _favourites.removeWhere((favourite) => favourite.stopId == stop.stopId);
      notifyListeners();

      try {
        await _localDb.cacheRemoveFavourite(stop.stopId);
      } catch (error) {
        debugPrint('Could not remove cached favourite: $error');
      }
      try {
        await _remote.removeFavourite(userId, stop.stopId);
      } catch (error) {
        debugPrint('Could not sync favourite removal to Supabase: $error');
      }
      return;
    }

    final favourite = FavouriteStop(
      stopId: stop.stopId,
      name: stop.name,
      lat: stop.lat,
      lng: stop.lng,
      savedAt: DateTime.now(),
    );
    _favourites.insert(0, favourite);
    notifyListeners();

    try {
      await _localDb.cacheAddFavourite(favourite);
    } catch (error) {
      debugPrint('Could not cache favourite: $error');
    }
    try {
      await _remote.addFavourite(userId, favourite);
    } catch (error) {
      debugPrint('Could not sync favourite addition to Supabase: $error');
    }
  }


  void clearOnSignOut() {
    _favourites = [];
    _isOffline = false;
    notifyListeners();
  }
}
