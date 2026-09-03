import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/eta_utils.dart';
import '../models/public_transport_plan.dart';
import '../models/route_model.dart';
import '../models/stop.dart';
import '../models/vehicle_position.dart';
import '../providers/transit_provider.dart';

enum RouteSortPreference { shortestTravelTime, fewestTransfers }

class RoutePlannerService {
  Future<List<PublicTransportPlan>> findRoutes({
    required LocationCandidate start,
    required LocationCandidate destination,
    required TransitProvider transit,
    DateTime? departureTime,
    RouteSortPreference preference = RouteSortPreference.shortestTravelTime,
  }) async {
    final departAt = departureTime ?? DateTime.now();
    if (transit.stops.isEmpty) return [];

    final startStops = _candidateStops(
      transit.stops,
      start,
      limit: start.stop == null ? 12 : 8,
    );
    final destinationStops = _candidateStops(
      transit.stops,
      destination,
      limit: destination.stop == null ? 16 : 12,
    );

    final plans = <PublicTransportPlan>[];
    for (final startStop in startStops) {
      final startRouteIds = await transit.routeIdsForStop(startStop);
      for (final endStop in destinationStops) {
        final endRouteIds = await transit.routeIdsForStop(endStop);
        final directRouteIds = startRouteIds.intersection(endRouteIds);
        for (final routeId in directRouteIds) {
          final route = _routeById(transit.routes, routeId);
          final plan = _buildDirectPlan(
            start: start,
            destination: destination,
            startStop: startStop,
            endStop: endStop,
            route: route,
            transit: transit,
            departureTime: departAt,
          );
          plans.add(plan);
        }

        if (directRouteIds.isEmpty) {
          plans.addAll(
            await _findOneTransferPlans(
              start: start,
              destination: destination,
              startStop: startStop,
              endStop: endStop,
              startRouteIds: startRouteIds,
              endRouteIds: endRouteIds,
              transit: transit,
              departureTime: departAt,
            ),
          );
        }
      }
    }

    if (plans.isEmpty) {
      for (final startStop in startStops) {
        final startRouteIds = await transit.routeIdsForStop(startStop);
        plans.addAll(
          await _findClosestReachablePlans(
            start: start,
            destination: destination,
            startStop: startStop,
            startRouteIds: startRouteIds,
            transit: transit,
            departureTime: departAt,
          ),
        );
        if (plans.length >= 3) break;
      }
    }

    plans.sort((a, b) {
      if (preference == RouteSortPreference.fewestTransfers) {
        final transfers = a.transfers.compareTo(b.transfers);
        if (transfers != 0) return transfers;
        final walking = a.walkingMinutes.compareTo(b.walkingMinutes);
        if (walking != 0) return walking;
      }
      final duration = a.totalDurationMinutes.compareTo(b.totalDurationMinutes);
      if (duration != 0) return duration;
      final transfers = a.transfers.compareTo(b.transfers);
      if (transfers != 0) return transfers;
      return a.walkingMinutes.compareTo(b.walkingMinutes);
    });

    final unique = <String, PublicTransportPlan>{};
    for (final plan in plans) {
      unique.putIfAbsent(
        '${plan.routeSummary}-${plan.legs.first.endName}-${plan.legs.last.startName}',
        () => plan,
      );
    }
    return unique.values.take(3).toList();
  }

  Future<List<PublicTransportPlan>> _findClosestReachablePlans({
    required LocationCandidate start,
    required LocationCandidate destination,
    required Stop startStop,
    required Set<String> startRouteIds,
    required TransitProvider transit,
    required DateTime departureTime,
  }) async {
    final stopsById = {for (final stop in transit.stops) stop.stopId: stop};
    final fallbackPlans = <PublicTransportPlan>[];

    for (final routeId in startRouteIds) {
      final route = _routeById(transit.routes, routeId);

      final servedStopIds = await transit.stopIdsForRoute(routeId);
      Stop? bestStop;
      var bestDistance = double.infinity;

      for (final stopId in servedStopIds) {
        if (stopId == startStop.stopId) continue;
        final stop = stopsById[stopId];
        if (stop == null) continue;

        final distanceToDestination = Geolocator.distanceBetween(
          stop.lat,
          stop.lng,
          destination.coordinate.latitude,
          destination.coordinate.longitude,
        );
        if (distanceToDestination < bestDistance) {
          bestDistance = distanceToDestination;
          bestStop = stop;
        }
      }

      if (bestStop == null) continue;
      fallbackPlans.add(
        _buildDirectPlan(
          start: start,
          destination: destination,
          startStop: startStop,
          endStop: bestStop,
          route: route,
          transit: transit,
          departureTime: departureTime,
        ),
      );
    }

    fallbackPlans.sort((a, b) {
      final walking = a.walkingMetres.compareTo(b.walkingMetres);
      if (walking != 0) return walking;
      return a.totalDurationMinutes.compareTo(b.totalDurationMinutes);
    });
    return fallbackPlans.take(3).toList();
  }

  Future<List<PublicTransportPlan>> _findOneTransferPlans({
    required LocationCandidate start,
    required LocationCandidate destination,
    required Stop startStop,
    required Stop endStop,
    required Set<String> startRouteIds,
    required Set<String> endRouteIds,
    required TransitProvider transit,
    required DateTime departureTime,
  }) async {
    final transferPlans = <PublicTransportPlan>[];
    final stopsById = {for (final stop in transit.stops) stop.stopId: stop};

    for (final firstRouteId in startRouteIds) {
      final firstRouteStopIds = await transit.stopIdsForRoute(firstRouteId);
      for (final secondRouteId in endRouteIds) {
        if (secondRouteId == firstRouteId) continue;

        final secondRouteStopIds =
            (await transit.stopIdsForRoute(secondRouteId)).toSet();
        final transferStopIds = firstRouteStopIds
            .where(
              (stopId) =>
                  secondRouteStopIds.contains(stopId) &&
                  stopId != startStop.stopId &&
                  stopId != endStop.stopId,
            )
            .toList();

        transferStopIds.sort((a, b) {
          final stopA = stopsById[a];
          final stopB = stopsById[b];
          if (stopA == null || stopB == null) return 0;
          final scoreA = _transferScore(startStop, stopA, endStop);
          final scoreB = _transferScore(startStop, stopB, endStop);
          return scoreA.compareTo(scoreB);
        });

        for (final transferStopId in transferStopIds.take(2)) {
          final transferStop = stopsById[transferStopId];
          if (transferStop == null) continue;

          transferPlans.add(
            _buildTransferPlan(
              start: start,
              destination: destination,
              startStop: startStop,
              transferStop: transferStop,
              endStop: endStop,
              firstRoute: _routeById(transit.routes, firstRouteId),
              secondRoute: _routeById(transit.routes, secondRouteId),
              transit: transit,
              departureTime: departureTime,
            ),
          );

          if (transferPlans.length >= 8) return transferPlans;
        }
      }
    }

    return transferPlans;
  }

  double _transferScore(Stop startStop, Stop transferStop, Stop endStop) {
    return Geolocator.distanceBetween(
          startStop.lat,
          startStop.lng,
          transferStop.lat,
          transferStop.lng,
        ) +
        Geolocator.distanceBetween(
          transferStop.lat,
          transferStop.lng,
          endStop.lat,
          endStop.lng,
        );
  }

  List<Stop> _candidateStops(
    List<Stop> stops,
    LocationCandidate location, {
    required int limit,
  }) {
    final nearby = _nearbyStops(stops, location.coordinate, limit);
    if (location.stop == null) return nearby;

    final byId = <String, Stop>{location.stop!.stopId: location.stop!};
    for (final stop in nearby) {
      byId.putIfAbsent(stop.stopId, () => stop);
    }
    return byId.values.toList();
  }

  PublicTransportPlan _buildTransferPlan({
    required LocationCandidate start,
    required LocationCandidate destination,
    required Stop startStop,
    required Stop transferStop,
    required Stop endStop,
    required TransitRoute firstRoute,
    required TransitRoute secondRoute,
    required TransitProvider transit,
    required DateTime departureTime,
  }) {
    final walkToStart = Geolocator.distanceBetween(
      start.coordinate.latitude,
      start.coordinate.longitude,
      startStop.lat,
      startStop.lng,
    );
    final firstRideDistance = Geolocator.distanceBetween(
      startStop.lat,
      startStop.lng,
      transferStop.lat,
      transferStop.lng,
    );
    final secondRideDistance = Geolocator.distanceBetween(
      transferStop.lat,
      transferStop.lng,
      endStop.lat,
      endStop.lng,
    );
    final walkToDestination = Geolocator.distanceBetween(
      endStop.lat,
      endStop.lng,
      destination.coordinate.latitude,
      destination.coordinate.longitude,
    );

    final firstVehicle =
        _nearestVehicleForRoute(transit, firstRoute.routeId, startStop);
    final secondVehicle =
        _nearestVehicleForRoute(transit, secondRoute.routeId, transferStop);
    final firstWait = firstVehicle == null
        ? 8
        : _etaMinutes(estimateEtaLabel(
            transit.distanceToVehicle(startStop, firstVehicle)));
    final secondWait = secondVehicle == null
        ? 8
        : _etaMinutes(estimateEtaLabel(
            transit.distanceToVehicle(transferStop, secondVehicle)));
    final walkStartMinutes = _walkingMinutes(walkToStart);
    final firstRideMinutes = (firstRideDistance / 330).ceil().clamp(4, 90);
    const transferWalkMinutes = 3;
    final secondRideMinutes = (secondRideDistance / 330).ceil().clamp(4, 90);
    final walkEndMinutes = _walkingMinutes(walkToDestination);

    final firstDeparture =
        departureTime.add(Duration(minutes: walkStartMinutes + firstWait));
    final firstArrival =
        firstDeparture.add(Duration(minutes: firstRideMinutes));
    final secondDeparture = firstArrival.add(
      Duration(minutes: transferWalkMinutes + secondWait),
    );
    final secondArrival =
        secondDeparture.add(Duration(minutes: secondRideMinutes));
    final arrival = secondArrival.add(Duration(minutes: walkEndMinutes));

    return PublicTransportPlan(
      startName: start.name,
      destinationName: destination.name,
      route: firstRoute,
      vehicle: firstVehicle,
      departureTime: departureTime,
      arrivalTime: arrival,
      estimatedFare:
          _estimateFare(firstRideDistance + secondRideDistance + 1200),
      realtimeAvailable: transit.vehiclesStatus == LoadStatus.ready &&
          transit.vehicles.isNotEmpty,
      legs: [
        RouteLeg(
          type: LegType.walking,
          startName: start.name,
          endName: startStop.name,
          startCoordinate: start.coordinate,
          endCoordinate: LatLng(startStop.lat, startStop.lng),
          durationMinutes: walkStartMinutes,
          distanceMetres: walkToStart,
        ),
        RouteLeg(
          type: LegType.bus,
          startName: startStop.name,
          endName: transferStop.name,
          startCoordinate: LatLng(startStop.lat, startStop.lng),
          endCoordinate: LatLng(transferStop.lat, transferStop.lng),
          durationMinutes: firstWait + firstRideMinutes,
          distanceMetres: firstRideDistance,
          routeNumber: firstRoute.displayLabel,
          routeName: firstRoute.longName,
          departureTime: firstDeparture,
          arrivalTime: firstArrival,
          realtimeEta: firstVehicle == null
              ? null
              : estimateEtaLabel(
                  transit.distanceToVehicle(startStop, firstVehicle)),
        ),
        RouteLeg(
          type: LegType.walking,
          startName: transferStop.name,
          endName: transferStop.name,
          startCoordinate: LatLng(transferStop.lat, transferStop.lng),
          endCoordinate: LatLng(transferStop.lat, transferStop.lng),
          durationMinutes: transferWalkMinutes,
          distanceMetres: 80,
        ),
        RouteLeg(
          type: LegType.bus,
          startName: transferStop.name,
          endName: endStop.name,
          startCoordinate: LatLng(transferStop.lat, transferStop.lng),
          endCoordinate: LatLng(endStop.lat, endStop.lng),
          durationMinutes: secondWait + secondRideMinutes,
          distanceMetres: secondRideDistance,
          routeNumber: secondRoute.displayLabel,
          routeName: secondRoute.longName,
          departureTime: secondDeparture,
          arrivalTime: secondArrival,
          realtimeEta: secondVehicle == null
              ? null
              : estimateEtaLabel(
                  transit.distanceToVehicle(transferStop, secondVehicle)),
        ),
        RouteLeg(
          type: LegType.walking,
          startName: endStop.name,
          endName: destination.name,
          startCoordinate: LatLng(endStop.lat, endStop.lng),
          endCoordinate: destination.coordinate,
          durationMinutes: walkEndMinutes,
          distanceMetres: walkToDestination,
        ),
      ],
    );
  }

  PublicTransportPlan _buildDirectPlan({
    required LocationCandidate start,
    required LocationCandidate destination,
    required Stop startStop,
    required Stop endStop,
    required TransitRoute route,
    required TransitProvider transit,
    required DateTime departureTime,
  }) {
    final walkToStart = Geolocator.distanceBetween(
      start.coordinate.latitude,
      start.coordinate.longitude,
      startStop.lat,
      startStop.lng,
    );
    final rideDistance = Geolocator.distanceBetween(
      startStop.lat,
      startStop.lng,
      endStop.lat,
      endStop.lng,
    );
    final walkToDestination = Geolocator.distanceBetween(
      endStop.lat,
      endStop.lng,
      destination.coordinate.latitude,
      destination.coordinate.longitude,
    );

    final vehicle = _nearestVehicleForRoute(transit, route.routeId, startStop);
    final waitMinutes = vehicle == null
        ? 8
        : _etaMinutes(
            estimateEtaLabel(transit.distanceToVehicle(startStop, vehicle)));
    final walkStartMinutes = _walkingMinutes(walkToStart);
    final rideMinutes = (rideDistance / 330).ceil().clamp(4, 90);
    final walkEndMinutes = _walkingMinutes(walkToDestination);
    final busDeparture =
        departureTime.add(Duration(minutes: walkStartMinutes + waitMinutes));
    final busArrival = busDeparture.add(Duration(minutes: rideMinutes));
    final arrival = busArrival.add(Duration(minutes: walkEndMinutes));

    return PublicTransportPlan(
      startName: start.name,
      destinationName: destination.name,
      route: route,
      vehicle: vehicle,
      departureTime: departureTime,
      arrivalTime: arrival,
      estimatedFare: _estimateFare(rideDistance),
      realtimeAvailable: transit.vehiclesStatus == LoadStatus.ready &&
          transit.vehicles.isNotEmpty,
      legs: [
        RouteLeg(
          type: LegType.walking,
          startName: start.name,
          endName: startStop.name,
          startCoordinate: start.coordinate,
          endCoordinate: LatLng(startStop.lat, startStop.lng),
          durationMinutes: walkStartMinutes,
          distanceMetres: walkToStart,
        ),
        RouteLeg(
          type: LegType.bus,
          startName: startStop.name,
          endName: endStop.name,
          startCoordinate: LatLng(startStop.lat, startStop.lng),
          endCoordinate: LatLng(endStop.lat, endStop.lng),
          durationMinutes: waitMinutes + rideMinutes,
          distanceMetres: rideDistance,
          routeNumber: route.displayLabel,
          routeName: route.longName,
          departureTime: busDeparture,
          arrivalTime: busArrival,
          stops: null,
          realtimeEta: vehicle == null
              ? null
              : estimateEtaLabel(transit.distanceToVehicle(startStop, vehicle)),
        ),
        RouteLeg(
          type: LegType.walking,
          startName: endStop.name,
          endName: destination.name,
          startCoordinate: LatLng(endStop.lat, endStop.lng),
          endCoordinate: destination.coordinate,
          durationMinutes: walkEndMinutes,
          distanceMetres: walkToDestination,
        ),
      ],
    );
  }

  List<Stop> _nearbyStops(List<Stop> stops, LatLng coordinate, int limit) {
    final sorted = [...stops]..sort(
        (a, b) => Geolocator.distanceBetween(
          coordinate.latitude,
          coordinate.longitude,
          a.lat,
          a.lng,
        ).compareTo(
          Geolocator.distanceBetween(
            coordinate.latitude,
            coordinate.longitude,
            b.lat,
            b.lng,
          ),
        ),
      );
    return sorted.take(limit).toList();
  }

  TransitRoute _routeById(List<TransitRoute> routes, String routeId) {
    for (final route in routes) {
      if (route.routeId == routeId) return route;
    }
    return TransitRoute(routeId: routeId, shortName: routeId, longName: '');
  }

  VehiclePosition? _nearestVehicleForRoute(
    TransitProvider transit,
    String routeId,
    Stop startStop,
  ) {
    final vehicles =
        transit.vehicles.where((vehicle) => vehicle.routeId == routeId).toList()
          ..sort(
            (a, b) => transit
                .distanceToVehicle(startStop, a)
                .compareTo(transit.distanceToVehicle(startStop, b)),
          );
    return vehicles.isEmpty ? null : vehicles.first;
  }

  int _walkingMinutes(double metres) => (metres / 80).ceil().clamp(1, 60);

  int _etaMinutes(String label) =>
      int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '') ?? 1;

  double _estimateFare(double rideMetres) {
    final fare = 1.2 + (rideMetres / 1000 * 0.35);
    return double.parse(fare.clamp(1.2, 6.0).toStringAsFixed(2));
  }
}
