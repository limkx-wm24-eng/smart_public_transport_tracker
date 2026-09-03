import 'package:latlong2/latlong.dart';

import '../core/eta_utils.dart';
import '../models/stop.dart';
import '../models/vehicle_position.dart';
import 'gtfs_static_service.dart';

/// Builds a schedule-aware ETA (see [estimateSmartEta] in eta_utils.dart)
/// for a live bus approaching a target stop.
///
/// Distance ÷ assumed speed alone doesn't know how many stops a bus still
/// has to serve before yours. This works that out by:
/// 1. Loading the bus's GTFS trip stop sequence (stop_times.txt).
/// 2. Finding which stop in that sequence the bus is currently nearest to
///    (an approximation of "where along the route it currently is",
///    since GTFS-RT only gives us lat/lng, not a stop-sequence position).
/// 3. Counting how many stops separate that position from the target stop.
///
/// Falls back to plain distance/speed whenever the schedule can't place
/// the bus confidently — no trip ID, the target stop isn't on this trip,
/// or the bus appears to have already passed it on this pass.
class EtaEstimationService {
  EtaEstimationService({GtfsStaticService? staticService})
      : _staticService = staticService ?? GtfsStaticService();

  final GtfsStaticService _staticService;
  static const Distance _distance = Distance();

  /// [distanceMetres] should already be the straight-line distance from
  /// [vehicle] to [targetStop] (callers already have this via
  /// TransitProvider.distanceToVehicle) — reused here as the fallback
  /// estimate and as the travel-time component of the schedule-aware one.
  /// [allStops] is TransitProvider's already-loaded stop list, used to
  /// look up coordinates for the stops on the bus's trip.
  Future<SmartEtaResult> estimate({
    required VehiclePosition vehicle,
    required Stop targetStop,
    required double distanceMetres,
    required List<Stop> allStops,
  }) async {
    final tripId = vehicle.tripId;
    if (tripId == null || tripId.isEmpty) {
      return estimateSmartEta(distanceMetres: distanceMetres);
    }

    final List<String> stopIds;
    try {
      stopIds = await _staticService.getOrderedStopIdsForTrip(tripId);
    } catch (_) {
      return estimateSmartEta(distanceMetres: distanceMetres);
    }

    if (stopIds.isEmpty) {
      return estimateSmartEta(distanceMetres: distanceMetres);
    }

    final targetIndex = stopIds.indexOf(targetStop.stopId);
    if (targetIndex == -1) {
      // This trip doesn't actually serve the target stop.
      return estimateSmartEta(distanceMetres: distanceMetres);
    }

    final stopsById = {for (final stop in allStops) stop.stopId: stop};

    var nearestIndex = -1;
    var nearestDistance = double.infinity;
    final vehicleLocation = LatLng(vehicle.lat, vehicle.lng);

    for (var i = 0; i < stopIds.length; i++) {
      final candidate = stopsById[stopIds[i]];
      if (candidate == null) continue;

      final d = _distance.as(
        LengthUnit.Meter,
        vehicleLocation,
        LatLng(candidate.lat, candidate.lng),
      );

      if (d < nearestDistance) {
        nearestDistance = d;
        nearestIndex = i;
      }
    }

    if (nearestIndex == -1 || targetIndex <= nearestIndex) {
      // Either no stop on the trip had known coordinates, or the target
      // stop is at/behind the bus's current position on this pass — the
      // plain distance estimate is the safer fallback rather than
      // reporting a nonsensical negative stop count.
      return estimateSmartEta(distanceMetres: distanceMetres);
    }

    return estimateSmartEta(
      distanceMetres: distanceMetres,
      stopsRemaining: targetIndex - nearestIndex,
    );
  }
}