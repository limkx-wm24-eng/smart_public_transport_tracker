import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart' as gtfsrt;
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/vehicle_position.dart';

class GtfsRealtimeService {
  Future<List<VehiclePosition>> fetchVehiclePositions() async {
    final allVehicles = <VehiclePosition>[];
    final failures = <String>[];

    for (final category in AppConstants.gtfsRealtimeCategories) {
      try {
        final vehicles = await _fetchVehiclePositionsForCategory(category);
        allVehicles.addAll(vehicles);
      } catch (error) {
        failures.add('$category: $error');
      }
    }

    if (allVehicles.isEmpty &&
        failures.length == AppConstants.gtfsRealtimeCategories.length) {
      throw Exception(
        'All GTFS realtime feeds failed: ${failures.join('; ')}',
      );
    }

    debugPrint(
      'Combined GTFS-RT vehicles: ${allVehicles.length}',
    );

    return allVehicles;
  }

  Future<List<VehiclePosition>> _fetchVehiclePositionsForCategory(
    String category,
  ) async {
    final uri = Uri.parse(
      '${AppConstants.gtfsRealtimeBaseUrl}?category=$category',
    );

    debugPrint(
      '====================================',
    );

    debugPrint(
      'GTFS-RT request [$category]: $uri',
    );





    late http.Response response;

    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'GTFS realtime request timed out.',
      );
    } catch (e) {
      throw Exception(
        'Unable to contact GTFS realtime service: $e',
      );
    }

    debugPrint(
      'GTFS-RT HTTP status: '
      '${response.statusCode}',
    );

    debugPrint(
      'GTFS-RT response size: '
      '${response.bodyBytes.length} bytes',
    );

    debugPrint(
      'GTFS-RT content-type: '
      '${response.headers['content-type']}',
    );





    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch realtime feed. '
        'HTTP ${response.statusCode}',
      );
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception(
        'Realtime GTFS feed returned '
        'an empty response.',
      );
    }





    late gtfsrt.FeedMessage feed;

    try {
      feed = gtfsrt.FeedMessage.fromBuffer(
        response.bodyBytes,
      );
    } catch (e) {
      debugPrint(
        'GTFS protobuf decoding error: $e',
      );

      throw Exception(
        'Unable to decode GTFS realtime data: $e',
      );
    }

    debugPrint(
      'Total GTFS entities: '
      '${feed.entity.length}',
    );





    int vehicleEntityCount = 0;
    int noVehicleCount = 0;
    int noPositionCount = 0;
    int invalidCoordinateCount = 0;

    final now = DateTime.now();

    final vehicles = <VehiclePosition>[];





    for (final entity in feed.entity) {




      if (!entity.hasVehicle()) {
        noVehicleCount++;
        continue;
      }

      vehicleEntityCount++;

      final vehicle = entity.vehicle;





      if (!vehicle.hasPosition()) {
        noPositionCount++;
        continue;
      }

      final position = vehicle.position;

      final lat = position.latitude.toDouble();
      final lng = position.longitude.toDouble();





      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        invalidCoordinateCount++;
        continue;
      }

      if (lat == 0 && lng == 0) {
        invalidCoordinateCount++;
        continue;
      }





      String vehicleId =
          entity.id.isNotEmpty ? entity.id : 'vehicle-${vehicles.length + 1}';







      if (vehicle.hasVehicle()) {
        if (vehicle.vehicle.hasId() && vehicle.vehicle.id.isNotEmpty) {
          vehicleId = vehicle.vehicle.id;
        }
      }





      String? routeId;

      if (vehicle.hasTrip()) {
        if (vehicle.trip.hasRouteId() && vehicle.trip.routeId.isNotEmpty) {
          routeId = vehicle.trip.routeId;
        }
      }





      String? tripId;

      if (vehicle.hasTrip()) {
        if (vehicle.trip.hasTripId() && vehicle.trip.tripId.isNotEmpty) {
          tripId = vehicle.trip.tripId;
        }
      }





      double? bearing;

      if (position.hasBearing()) {
        bearing = position.bearing.toDouble();
      }





      vehicles.add(
        VehiclePosition(
          vehicleId: vehicleId,
          routeId: routeId,
          tripId: tripId,
          lat: lat,
          lng: lng,
          bearing: bearing,
          fetchedAt: now,
        ),
      );
    }





    debugPrint(
      'Vehicle entities: '
      '$vehicleEntityCount',
    );

    debugPrint(
      'Entities without vehicle: '
      '$noVehicleCount',
    );

    debugPrint(
      'Vehicles without position: '
      '$noPositionCount',
    );

    debugPrint(
      'Invalid coordinates: '
      '$invalidCoordinateCount',
    );

    debugPrint(
      'GTFS-RT parsed vehicles: '
      '${vehicles.length}',
    );





    if (vehicles.isNotEmpty) {
      final first = vehicles.first;

      debugPrint(
        'First bus:',
      );

      debugPrint(
        'Vehicle ID: '
        '${first.vehicleId}',
      );

      debugPrint(
        'Route ID: '
        '${first.routeId}',
      );

      debugPrint(
        'Trip ID: '
        '${first.tripId}',
      );

      debugPrint(
        'Latitude: '
        '${first.lat}',
      );

      debugPrint(
        'Longitude: '
        '${first.lng}',
      );

      debugPrint(
        'Bearing: '
        '${first.bearing}',
      );
    }





    for (final bus in vehicles.take(5)) {
      debugPrint(
        'Bus ${bus.vehicleId} | '
        'Route=${bus.routeId} | '
        'Trip=${bus.tripId} | '
        '${bus.lat}, ${bus.lng}',
      );
    }

    debugPrint(
      '====================================',
    );

    return vehicles;
  }
}
