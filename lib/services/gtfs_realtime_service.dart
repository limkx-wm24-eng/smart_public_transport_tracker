import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart'
as gtfsrt;
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/vehicle_position.dart';

class GtfsRealtimeService {
  Future<List<VehiclePosition>> fetchVehiclePositions() async {
    final uri = Uri.parse(
      AppConstants.gtfsRealtimeUrl,
    );

    debugPrint(
      '====================================',
    );

    debugPrint(
      'GTFS-RT request: $uri',
    );

    // =========================================================
    // DOWNLOAD GTFS REALTIME DATA
    // =========================================================

    final response = await http
        .get(uri)
        .timeout(
      const Duration(seconds: 15),
    );

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

    // =========================================================
    // CHECK HTTP RESPONSE
    // =========================================================

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

    // =========================================================
    // DECODE PROTOBUF
    // =========================================================

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

    // =========================================================
    // DEBUG COUNTERS
    // =========================================================

    int vehicleEntityCount = 0;
    int noVehicleCount = 0;
    int noPositionCount = 0;
    int invalidCoordinateCount = 0;

    final now = DateTime.now();

    final vehicles =
    <VehiclePosition>[];

    // =========================================================
    // PARSE LIVE VEHICLES
    // =========================================================

    for (final entity in feed.entity) {
      // -------------------------------------------------------
      // CHECK VEHICLE DATA
      // -------------------------------------------------------

      if (!entity.hasVehicle()) {
        noVehicleCount++;

        continue;
      }

      vehicleEntityCount++;

      final vehicle =
          entity.vehicle;

      // -------------------------------------------------------
      // CHECK GPS POSITION
      // -------------------------------------------------------

      if (!vehicle.hasPosition()) {
        noPositionCount++;

        continue;
      }

      final position =
          vehicle.position;

      final lat =
      position.latitude.toDouble();

      final lng =
      position.longitude.toDouble();

      // -------------------------------------------------------
      // VALIDATE COORDINATES
      // -------------------------------------------------------

      if (lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        invalidCoordinateCount++;

        continue;
      }

      if (lat == 0 &&
          lng == 0) {
        invalidCoordinateCount++;

        continue;
      }

      // =======================================================
      // VEHICLE ID
      // =======================================================

      String vehicleId =
          entity.id;

      if (vehicle.hasVehicle()) {
        if (vehicle.vehicle.hasId() &&
            vehicle.vehicle.id.isNotEmpty) {
          vehicleId =
              vehicle.vehicle.id;
        }
      }

      // =======================================================
      // ROUTE ID
      // =======================================================

      String? routeId;

      if (vehicle.hasTrip()) {
        if (vehicle.trip.hasRouteId() &&
            vehicle.trip.routeId.isNotEmpty) {
          routeId =
              vehicle.trip.routeId;
        }
      }

      // =======================================================
      // TRIP ID
      // =======================================================

      String? tripId;

      if (vehicle.hasTrip()) {
        if (vehicle.trip.hasTripId() &&
            vehicle.trip.tripId.isNotEmpty) {
          tripId =
              vehicle.trip.tripId;
        }
      }

      // =======================================================
      // BEARING
      // =======================================================

      double? bearing;

      if (position.hasBearing()) {
        bearing =
            position.bearing.toDouble();
      }

      // =======================================================
      // CREATE VEHICLE POSITION
      // =======================================================

      vehicles.add(
        VehiclePosition(
          vehicleId: vehicleId,
          routeId: routeId,

          // ⭐ NEW
          tripId: tripId,

          lat: lat,
          lng: lng,
          bearing: bearing,
          fetchedAt: now,
        ),
      );
    }

    // =========================================================
    // DEBUG RESULT
    // =========================================================

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

    // =========================================================
    // SHOW SAMPLE BUS
    // =========================================================

    if (vehicles.isNotEmpty) {
      final first =
          vehicles.first;

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

    // =========================================================
    // PRINT FIRST FEW BUSES
    // =========================================================

    for (final bus
    in vehicles.take(5)) {
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