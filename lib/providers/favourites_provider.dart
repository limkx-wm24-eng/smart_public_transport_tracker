import 'package:flutter/foundation.dart';

import '../models/favourite_route.dart';
import '../models/route_model.dart';
import '../services/database_service.dart';

/// bus line search & favourites.
/// Purely local data: everything here lives in SQLite, nothing is fetched
/// from the network.
class FavouritesProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<FavouriteRoute> _favourites = [];
  List<FavouriteRoute> get favourites => _favourites;

  Future<void> load() async {
    _favourites = await _db.getFavouriteRoutes();
    notifyListeners();
  }

  bool isFavourite(String routeId) {
    return _favourites.any((f) => f.routeId == routeId);
  }

  Future<void> toggleFavourite(TransitRoute route) async {
    if (isFavourite(route.routeId)) {
      await _db.removeFavouriteRoute(route.routeId);
    } else {
      await _db.addFavouriteRoute(FavouriteRoute(
        routeId: route.routeId,
        shortName: route.shortName,
        longName: route.longName,
        savedAt: DateTime.now(),
      ));
    }
    await load();
  }
}