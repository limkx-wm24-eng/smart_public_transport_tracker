/// Represents one live vehicle from the GTFS-Realtime feed.
/// This is purely in-memory — realtime data should never be cached long-term,
/// it goes stale within seconds.
class VehiclePosition {
  final String vehicleId;
  final String? routeId;
  final double lat;
  final double lng;
  final double? bearing;
  final DateTime fetchedAt;

  const VehiclePosition({
    required this.vehicleId,
    this.routeId,
    required this.lat,
    required this.lng,
    this.bearing,
    required this.fetchedAt,
  });
}
