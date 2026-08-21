// A bus line recommended to the user because it currently has a live
// vehicle near their location. See RouteRecommendationService for how
// this is computed.
class RecommendedRoute {
  final String routeId;
  final String label;
  final double nearestVehicleDistanceMetres;
  final int vehicleCountNearby;

  const RecommendedRoute({
    required this.routeId,
    required this.label,
    required this.nearestVehicleDistanceMetres,
    required this.vehicleCountNearby,
  });

  String get distanceLabel {
    if (nearestVehicleDistanceMetres < 1000) {
      return '${nearestVehicleDistanceMetres.round()} m away';
    }
    return '${(nearestVehicleDistanceMetres / 1000).toStringAsFixed(1)} km away';
  }
}