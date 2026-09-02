import 'package:geolocator/geolocator.dart';

import '../core/eta_utils.dart';
import '../models/route_model.dart';
import '../models/stop.dart';
import '../models/vehicle_position.dart';
import '../providers/transit_provider.dart';

class JourneyPlan {
  const JourneyPlan({required this.destination, required this.nearestStop, required this.walkMetres, required this.route, required this.vehicle, required this.busEta, required this.destinationStop, required this.realtimeAvailable});
  final String destination;
  final Stop nearestStop;
  final double walkMetres;
  final TransitRoute? route;
  final VehiclePosition? vehicle;
  final String? busEta;
  final Stop? destinationStop;
  final bool realtimeAvailable;
  int get walkingMinutes => (walkMetres / 80).ceil().clamp(1, 99) as int;
  int? get journeyMinutes => route == null ? null : walkingMinutes + (busEta == null ? 20 : _etaMinutes(busEta!)) + 15;
  Map<String, dynamic> toContext(double latitude, double longitude) => {
    'currentLocation': {'la'
        '        titude': latitude, 'longitude': longitude},
    'destination': destination,
    'nearestStop': {'id': nearestStop.stopId, 'name': nearestStop.name, 'walkingMetres': walkMetres.round(), 'walkingMinutes': walkingMinutes},
    'destinationStop': destinationStop == null ? null : {'id': destinationStop!.stopId, 'name': destinationStop!.name},
    'selectedRoute': route == null ? null : {'id': route!.routeId, 'label': route!.displayLabel, 'name': route!.longName},
    'realtimeAvailable': realtimeAvailable,
    'relevantVehicle': vehicle == null ? null : {'id': vehicle!.vehicleId, 'latitude': vehicle!.lat, 'longitude': vehicle!.lng},
    'estimatedBusArrival': busEta,
    'estimatedTotalJourneyMinutes': journeyMinutes,
  };
}

int _etaMinutes(String label) => int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '') ?? 1;

class JourneyPlannerService {
  Future<JourneyPlan?> plan({required String destination, required double latitude, required double longitude, required TransitProvider transit}) async {
    if (transit.stops.isEmpty) return null;
    final nearby = [...transit.stops]..sort((a, b) => Geolocator.distanceBetween(latitude, longitude, a.lat, a.lng).compareTo(Geolocator.distanceBetween(latitude, longitude, b.lat, b.lng)));
    final nearest = nearby.first;
    final destinationMatches = transit.searchStopsLocally(destination);
    final destinationStop = destinationMatches.isEmpty ? null : destinationMatches.first;
    TransitRoute? route;
    if (destinationStop != null) {
      final startRoutes = await transit.routeIdsForStop(nearest);
      final endRoutes = await transit.routeIdsForStop(destinationStop);
      final matching = startRoutes.intersection(endRoutes);
      if (matching.isNotEmpty) {
        for (final candidate in transit.routes) {
          if (matching.contains(candidate.routeId)) {
            route = candidate;
            break;
          }
        }
      }
    }
    final vehicles = route == null ? <VehiclePosition>[] : transit.vehicles.where((v) => v.routeId == route!.routeId).toList();
    vehicles.sort((a, b) => transit.distanceToVehicle(nearest, a).compareTo(transit.distanceToVehicle(nearest, b)));
    final vehicle = vehicles.isEmpty ? null : vehicles.first;
    return JourneyPlan(destination: destination, nearestStop: nearest, walkMetres: Geolocator.distanceBetween(latitude, longitude, nearest.lat, nearest.lng) * 1.2, route: route, vehicle: vehicle, busEta: vehicle == null ? null : estimateEtaLabel(transit.distanceToVehicle(nearest, vehicle)), destinationStop: destinationStop, realtimeAvailable: transit.vehiclesStatus == LoadStatus.ready && transit.vehicles.isNotEmpty);
  }
}
