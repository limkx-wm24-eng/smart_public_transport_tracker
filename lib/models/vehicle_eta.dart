/// A live vehicle's estimated arrival at a specific stop, computed
/// client-side from its current position (see EtaService for the maths).
///
/// This is an ESTIMATE, not a scheduled/official arrival time — data.gov.my
/// doesn't publish a trip-updates feed yet (only vehicle positions), so we
/// approximate using straight-line distance and an assumed average speed.
class VehicleEta {
  final String vehicleId;
  final String routeLabel;
  final double distanceMetres;
  final int etaMinutes;

  const VehicleEta({
    required this.vehicleId,
    required this.routeLabel,
    required this.distanceMetres,
    required this.etaMinutes,
  });

  String get distanceLabel {
    if (distanceMetres < 1000) return '${distanceMetres.round()} m away';
    return '${(distanceMetres / 1000).toStringAsFixed(1)} km away';
  }

  String get etaLabel {
    if (etaMinutes <= 1) return 'Arriving now';
    return '~$etaMinutes min';
  }
}
