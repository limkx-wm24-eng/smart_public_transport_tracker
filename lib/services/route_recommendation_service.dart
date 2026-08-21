import 'package:geolocator/geolocator.dart';

import '../models/recommended_route.dart';
import '../models/route_model.dart';
import '../models/vehicle_position.dart';

/// Recommends bus lines to the user based on which routes currently have
/// a live vehicle near their GPS location.
///
/// This uses the same live vehicle-position feed as the map/ETA features —
/// no separate API call needed. A route is "nearby" if at least one of its
/// live vehicles is within [maxDistanceMetres] of the user.
class RouteRecommendationService {
  static const double _defaultMaxDistanceMetres = 3000;

  List<RecommendedRoute> recommendNearby({
    required double userLat,
    required double userLng,
    required List<VehiclePosition> vehicles,
    required List<TransitRoute> routes,
    double maxDistanceMetres = _defaultMaxDistanceMetres,
  }) {
    final routesById = {for (final r in routes) r.routeId: r};

    // Group vehicles by route, tracking the nearest one and a count.
    final nearestByRoute = <String, double>{};
    final countByRoute = <String, int>{};

    for (final v in vehicles) {
      if (v.routeId == null) continue;

      final distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        v.lat,
        v.lng,
      );

      if (distance > maxDistanceMetres) continue;

      countByRoute[v.routeId!] = (countByRoute[v.routeId!] ?? 0) + 1;
      final current = nearestByRoute[v.routeId!];
      if (current == null || distance < current) {
        nearestByRoute[v.routeId!] = distance;
      }
    }

    final results = nearestByRoute.entries.map((entry) {
      final route = routesById[entry.key];
      final label = route?.displayLabel ?? entry.key;
      return RecommendedRoute(
        routeId: entry.key,
        label: label,
        nearestVehicleDistanceMetres: entry.value,
        vehicleCountNearby: countByRoute[entry.key] ?? 1,
      );
    }).toList();

    results.sort((a, b) =>
        a.nearestVehicleDistanceMetres.compareTo(b.nearestVehicleDistanceMetres));

    return results;
  }
}