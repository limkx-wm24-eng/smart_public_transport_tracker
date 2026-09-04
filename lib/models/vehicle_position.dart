class VehiclePosition {
  final String vehicleId;
  final String? routeId;
  final String? tripId;

  final double lat;
  final double lng;
  final double? bearing;

  final DateTime fetchedAt;

  VehiclePosition({
    required this.vehicleId,
    this.routeId,
    this.tripId,
    required this.lat,
    required this.lng,
    this.bearing,
    required this.fetchedAt,
  });
}
