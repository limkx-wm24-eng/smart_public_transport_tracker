import 'package:flutter/foundation.dart';

import '../models/favourite_stop.dart';
import '../models/stop.dart';
import '../services/database_service.dart';

/// Manages the user's saved (favourite) stops.
/// Purely local data: everything here lives in shared_preferences, nothing
/// is fetched from the network.
class FavouritesProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<FavouriteStop> _favourites = [];
  List<FavouriteStop> get favourites => _favourites;

  Future<void> load() async {
    _favourites = await _db.getFavourites();
    notifyListeners();
  }

  bool isFavourite(String stopId) {
    return _favourites.any((f) => f.stopId == stopId);
  }

  Future<void> toggleFavourite(Stop stop) async {
    if (isFavourite(stop.stopId)) {
      await _db.removeFavourite(stop.stopId);
    } else {
      await _db.addFavourite(FavouriteStop(
        stopId: stop.stopId,
        name: stop.name,
        lat: stop.lat,
        lng: stop.lng,
        savedAt: DateTime.now(),
      ));
    }
    await load();
  }
}