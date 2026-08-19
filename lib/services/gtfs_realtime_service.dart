import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart' as gtfsrt;import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/vehicle_position.dart';

/// Fetches live vehicle positions from Malaysia's GTFS-Realtime feed.
///
/// The feed is binary Protocol Buffers — `gtfs_realtime_bindings` decodes it
/// for us, so we never have to touch raw bytes or compile .proto files.
class GtfsRealtimeService {
  Future<List<VehiclePosition>> fetchVehiclePositions() async {
    final response = await http.get(Uri.parse(AppConstants.gtfsRealtimeUrl));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch realtime feed: HTTP ${response.statusCode}');
    }

    final feed = gtfsrt.FeedMessage.fromBuffer(response.bodyBytes);
    final now = DateTime.now();
    final vehicles = <VehiclePosition>[];

    for (final entity in feed.entity) {
      if (!entity.hasVehicle()) continue;
      final v = entity.vehicle;
      if (!v.hasPosition()) continue;

      vehicles.add(VehiclePosition(
        vehicleId: entity.id,
        routeId: v.hasTrip() && v.trip.hasRouteId() ? v.trip.routeId : null,
        lat: v.position.latitude,
        lng: v.position.longitude,
        bearing: v.position.hasBearing() ? v.position.bearing : null,
        fetchedAt: now,
      ));
    }

    return vehicles;
  }
}
