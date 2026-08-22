import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/shape_point.dart';
import '../models/stop.dart';
import '../models/trip_model.dart';

class GtfsStaticService {
  Archive? _cachedArchive;

  // Parsed trips.txt / shapes.txt are comparatively expensive to re-parse
  // (shapes.txt in particular can have tens of thousands of rows), and
  // getRouteShapeForVehicle() calls fetchTrips() + fetchShapeForId() (which
  // itself calls fetchShapePoints()) every time a user opens a bus's live
  // map. Cache the parsed results the same way the raw archive is cached,
  // so repeat lookups just re-filter the same in-memory list.
  List<TransitTrip>? _cachedTrips;
  List<ShapePoint>? _cachedShapePoints;

  Future<Archive> _getArchive() async {
    if (_cachedArchive != null) {
      return _cachedArchive!;
    }

    final response = await http.get(
      Uri.parse(
        AppConstants.gtfsStaticUrl,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download GTFS-Static feed: '
            'HTTP ${response.statusCode}',
      );
    }

    final Uint8List bytes =
        response.bodyBytes;

    _cachedArchive =
        ZipDecoder().decodeBytes(bytes);

    return _cachedArchive!;
  }

  List<Map<String, dynamic>> _parseCsvFile(
      Archive archive,
      String fileName,
      ) {
    final file = archive.files.firstWhere(
          (f) =>
          f.name
              .toLowerCase()
              .endsWith(fileName),

      orElse: () => throw Exception(
        '$fileName not found in GTFS feed',
      ),
    );

    final content = utf8.decode(
      file.content as List<int>,
    );

    final rows =
    const CsvToListConverter(
      eol: '\n',
    ).convert(content);

    if (rows.isEmpty) {
      return [];
    }

    final headers = rows.first
        .map(
          (h) =>
          h.toString().trim(),
    )
        .toList();

    final parsed =
    <Map<String, dynamic>>[];

    for (final row
    in rows.skip(1)) {
      if (row.length !=
          headers.length) {
        continue;
      }

      parsed.add({
        for (var i = 0;
        i < headers.length;
        i++)
          headers[i]: row[i],
      });
    }

    return parsed;
  }

  // =========================================================
  // STOPS
  // =========================================================

  Future<List<Stop>>
  fetchStops() async {
    final archive =
    await _getArchive();

    final rows =
    _parseCsvFile(
      archive,
      'stops.txt',
    );

    final stops = <Stop>[];

    for (final row in rows) {
      final stop =
      Stop.fromCsvRow(row);

      if (stop.stopId.isNotEmpty) {
        stops.add(stop);
      }
    }

    return stops;
  }

  // =========================================================
  // ROUTES
  // =========================================================

  Future<List<TransitRoute>>
  fetchRoutes() async {
    final archive =
    await _getArchive();

    final rows =
    _parseCsvFile(
      archive,
      'routes.txt',
    );

    final routes =
    <TransitRoute>[];

    for (final row in rows) {
      final route =
      TransitRoute.fromCsvRow(
        row,
      );

      if (route.routeId.isNotEmpty) {
        routes.add(route);
      }
    }

    return routes;
  }

  // =========================================================
  // TRIPS
  // =========================================================

  Future<List<TransitTrip>>
  fetchTrips() async {
    if (_cachedTrips != null) {
      return _cachedTrips!;
    }

    final archive =
    await _getArchive();

    final rows =
    _parseCsvFile(
      archive,
      'trips.txt',
    );

    final trips =
    <TransitTrip>[];

    for (final row in rows) {
      final trip =
      TransitTrip.fromCsvRow(
        row,
      );

      if (trip.tripId.isNotEmpty) {
        trips.add(trip);
      }
    }

    _cachedTrips = trips;

    return trips;
  }

  // =========================================================
  // SHAPE POINTS
  // =========================================================

  Future<List<ShapePoint>>
  fetchShapePoints() async {
    if (_cachedShapePoints != null) {
      return _cachedShapePoints!;
    }

    final archive =
    await _getArchive();

    final rows =
    _parseCsvFile(
      archive,
      'shapes.txt',
    );

    final points =
    <ShapePoint>[];

    for (final row in rows) {
      final point =
      ShapePoint.fromCsvRow(
        row,
      );

      if (point.shapeId.isEmpty) {
        continue;
      }

      if (point.lat == 0 &&
          point.lng == 0) {
        continue;
      }

      points.add(point);
    }

    _cachedShapePoints = points;

    return points;
  }

  // =========================================================
  // FIND SHAPE ID FOR TRIP
  // =========================================================

  Future<String?>
  findShapeIdForTrip(
      String tripId,
      ) async {
    final trips =
    await fetchTrips();

    for (final trip in trips) {
      if (trip.tripId == tripId) {
        return trip.shapeId;
      }
    }

    return null;
  }

  // =========================================================
  // GET SHAPE POINTS FOR SHAPE ID
  // =========================================================

  Future<List<ShapePoint>>
  fetchShapeForId(
      String shapeId,
      ) async {
    final allPoints =
    await fetchShapePoints();

    final routePoints =
    allPoints.where(
          (point) =>
      point.shapeId == shapeId,
    ).toList();

    routePoints.sort(
          (a, b) =>
          a.sequence.compareTo(
            b.sequence,
          ),
    );

    return routePoints;
  }

  // =========================================================
  // CLEAR CACHE
  // =========================================================

  void clearCache() {
    _cachedArchive = null;
    _cachedTrips = null;
    _cachedShapePoints = null;
  }
}