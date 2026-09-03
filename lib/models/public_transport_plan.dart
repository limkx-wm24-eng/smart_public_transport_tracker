import 'package:latlong2/latlong.dart';

import 'route_model.dart';
import 'stop.dart';
import 'vehicle_position.dart';

enum LegType { walking, bus, train }

class RouteLeg {
  const RouteLeg({
    required this.type,
    required this.startName,
    required this.endName,
    required this.startCoordinate,
    required this.endCoordinate,
    required this.durationMinutes,
    required this.distanceMetres,
    this.routeNumber,
    this.routeName,
    this.departureTime,
    this.arrivalTime,
    this.stops,
    this.realtimeEta,
  });

  final LegType type;
  final String startName;
  final String endName;
  final LatLng startCoordinate;
  final LatLng endCoordinate;
  final int durationMinutes;
  final double distanceMetres;
  final String? routeNumber;
  final String? routeName;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final int? stops;
  final String? realtimeEta;
}

class PublicTransportPlan {
  const PublicTransportPlan({
    required this.startName,
    required this.destinationName,
    required this.route,
    required this.vehicle,
    required this.legs,
    required this.departureTime,
    required this.arrivalTime,
    required this.estimatedFare,
    required this.realtimeAvailable,
  });

  final String startName;
  final String destinationName;
  final TransitRoute route;
  final VehiclePosition? vehicle;
  final List<RouteLeg> legs;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final double? estimatedFare;
  final bool realtimeAvailable;

  int get totalDurationMinutes =>
      legs.fold(0, (total, leg) => total + leg.durationMinutes);

  int get transfers =>
      legs.where((leg) => leg.type != LegType.walking).length - 1;

  int get walkingMinutes => legs
      .where((leg) => leg.type == LegType.walking)
      .fold(0, (total, leg) => total + leg.durationMinutes);

  double get walkingMetres => legs
      .where((leg) => leg.type == LegType.walking)
      .fold(0, (total, leg) => total + leg.distanceMetres);

  String get routeSummary {
    final parts = <String>[];
    for (final leg in legs) {
      if (leg.type == LegType.walking) {
        if (parts.isEmpty || parts.last != 'Walk') parts.add('Walk');
      } else {
        parts.add(leg.routeNumber ?? leg.routeName ?? 'Transit');
      }
    }
    return parts.join(' -> ');
  }

  Map<String, dynamic> toAiContext() {
    return {
      'start': startName,
      'destination': destinationName,
      'totalDurationMinutes': totalDurationMinutes,
      'arrivalTime': arrivalTime.toIso8601String(),
      'estimatedFare': estimatedFare,
      'transfers': transfers,
      'walkingMinutes': walkingMinutes,
      'route': {
        'id': route.routeId,
        'label': route.displayLabel,
        'name': route.longName,
      },
      'liveVehicle': vehicle == null
          ? null
          : {
              'id': vehicle!.vehicleId,
              'routeId': vehicle!.routeId,
              'tripId': vehicle!.tripId,
            },
      'legs': legs
          .map(
            (leg) => {
              'type': leg.type.name,
              'startName': leg.startName,
              'endName': leg.endName,
              'durationMinutes': leg.durationMinutes,
              'distanceMetres': leg.distanceMetres.round(),
              'routeNumber': leg.routeNumber,
              'routeName': leg.routeName,
              'stops': leg.stops,
              'realtimeEta': leg.realtimeEta,
            },
          )
          .toList(),
      'realtimeAvailable': realtimeAvailable,
    };
  }
}

class LocationCandidate {
  const LocationCandidate({
    required this.name,
    required this.coordinate,
    this.stop,
  });

  final String name;
  final LatLng coordinate;
  final Stop? stop;
}
