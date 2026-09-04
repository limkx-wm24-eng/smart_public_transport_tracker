import 'package:latlong2/latlong.dart';

import '../core/eta_utils.dart';
import '../models/stop.dart';
import '../models/vehicle_position.dart';
import 'gtfs_static_service.dart';















class EtaEstimationService {
  EtaEstimationService({GtfsStaticService? staticService})
      : _staticService = staticService ?? GtfsStaticService();

  final GtfsStaticService _staticService;
  static const Distance _distance = Distance();







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




      return estimateSmartEta(distanceMetres: distanceMetres);
    }

    return estimateSmartEta(
      distanceMetres: distanceMetres,
      stopsRemaining: targetIndex - nearestIndex,
    );
  }
}
