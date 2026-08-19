import 'package:geolocator/geolocator.dart';

import '../models/route_model.dart';
import '../models/stop.dart';
import '../models/vehicle_eta.dart';
import '../models/vehicle_position.dart';

/// Computes an approximate ETA for live vehicles approaching a stop.
///
/// WHY THIS APPROACH: data.gov.my currently only publishes GTFS-Realtime
/// **vehicle positions**, not a trip-updates feed (official predicted
/// arrival times are on their roadmap, not live yet). So instead of a
/// scheduled prediction, we estimate arrival using:
///
///     eta_minutes = straight_line_distance / assumed_average_speed
///
/// This is a reasonable approximation for a student project, but it is
/// NOT the same as an official prediction — it doesn't account for the
/// actual road route, traffic, or upcoming stops the vehicle must serve
/// first. Document this limitation in your report/presentation; it's a
/// good thing to mention under "weaknesses of the module".
class EtaService {
  /// Vehicles further than this from a stop aren't shown — otherwise you'd
  /// list buses on the other side of the city that happen to share a route.
  static const double _maxRelevantDistanceMetres = 5000;

  /// Rough average speed for urban buses in KL traffic (~18 km/h).
  /// Tune this per city/route type if you want more accuracy later.
  static const double _assumedSpeedMetresPerMinute = 300;

  List<VehicleEta> estimateForStop({
    required Stop stop,
    required List<VehiclePosition> vehicles,
    required List<TransitRoute> routes,
  }) {
    final routesById = {for (final r in routes) r.routeId: r};
    final results = <VehicleEta>[];

    for (final v in vehicles) {
      final distance = Geolocator.distanceBetween(
        stop.lat,
        stop.lng,
        v.lat,
        v.lng,
      );

      if (distance > _maxRelevantDistanceMetres) continue;

      final route = v.routeId != null ? routesById[v.routeId] : null;
      final label = route?.displayLabel ?? (v.routeId ?? 'Unknown route');

      final etaMinutes = (distance / _assumedSpeedMetresPerMinute).ceil();

      results.add(VehicleEta(
        vehicleId: v.vehicleId,
        routeLabel: label,
        distanceMetres: distance,
        etaMinutes: etaMinutes,
      ));
    }

    results.sort((a, b) => a.distanceMetres.compareTo(b.distanceMetres));
    return results;
  }
}
