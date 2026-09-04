import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/shape_point.dart';
import '../models/stop.dart';
import '../models/trip_model.dart';







List<Map<String, dynamic>> _parseCsvContent(String content) {
  final rows = const CsvToListConverter(eol: '\n').convert(content);

  if (rows.isEmpty) {
    return [];
  }

  final headers = rows.first.map((h) => h.toString().trim()).toList();

  final parsed = <Map<String, dynamic>>[];

  for (final row in rows.skip(1)) {
    if (row.length != headers.length) {
      continue;
    }

    parsed.add({
      for (var i = 0; i < headers.length; i++) headers[i]: row[i],
    });
  }

  return parsed;
}

class GtfsStaticService {
  GtfsStaticService({String? staticUrl})
      : _staticUrl = staticUrl ?? AppConstants.gtfsStaticUrl;

  final String _staticUrl;
  Archive? _cachedArchive;







  List<TransitTrip>? _cachedTrips;
  List<ShapePoint>? _cachedShapePoints;
  final Map<String, String?> _tripIdByStopId = {};
  Map<String, Set<String>>? _routeIdsByStopId;
  Map<String, List<String>>? _stopIdsByRouteId;
  Map<String, List<String>>? _orderedStopIdsByTrip;
  Future<void>? _stopSequenceIndexFuture;

  Future<Archive> _getArchive() async {
    if (_cachedArchive != null) {
      return _cachedArchive!;
    }





    final response = await http
        .get(
          Uri.parse(_staticUrl),
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception(
            'Timed out downloading GTFS-Static feed',
          ),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download GTFS-Static feed: '
        'HTTP ${response.statusCode}',
      );
    }

    final Uint8List bytes = response.bodyBytes;

    _cachedArchive = ZipDecoder().decodeBytes(bytes);

    return _cachedArchive!;
  }

  Future<List<Map<String, dynamic>>> _parseCsvFile(
    Archive archive,
    String fileName,
  ) async {
    final file = archive.files.firstWhere(
      (f) => f.name.toLowerCase().endsWith(fileName),
      orElse: () => throw Exception(
        '$fileName not found in GTFS feed',
      ),
    );

    final content = utf8.decode(
      file.content as List<int>,
    );




    return compute(_parseCsvContent, content);
  }





  Future<List<Stop>> fetchStops() async {
    final archive = await _getArchive();

    final rows = await _parseCsvFile(
      archive,
      'stops.txt',
    );

    final stops = <Stop>[];

    for (final row in rows) {
      final stop = Stop.fromCsvRow(row);

      if (stop.stopId.isNotEmpty) {
        stops.add(stop);
      }
    }

    return stops;
  }





  Future<List<TransitRoute>> fetchRoutes() async {
    final archive = await _getArchive();

    final rows = await _parseCsvFile(
      archive,
      'routes.txt',
    );

    final routes = <TransitRoute>[];

    for (final row in rows) {
      final route = TransitRoute.fromCsvRow(
        row,
      );

      if (route.routeId.isNotEmpty) {
        routes.add(route);
      }
    }

    return routes;
  }





  Future<List<TransitTrip>> fetchTrips() async {
    if (_cachedTrips != null) {
      return _cachedTrips!;
    }

    final archive = await _getArchive();

    final rows = await _parseCsvFile(
      archive,
      'trips.txt',
    );

    final trips = <TransitTrip>[];

    for (final row in rows) {
      final trip = TransitTrip.fromCsvRow(
        row,
      );

      if (trip.tripId.isNotEmpty) {
        trips.add(trip);
      }
    }

    _cachedTrips = trips;

    return trips;
  }





  Future<List<ShapePoint>> fetchShapePoints() async {
    if (_cachedShapePoints != null) {
      return _cachedShapePoints!;
    }

    final archive = await _getArchive();

    final rows = await _parseCsvFile(
      archive,
      'shapes.txt',
    );

    final points = <ShapePoint>[];

    for (final row in rows) {
      final point = ShapePoint.fromCsvRow(
        row,
      );

      if (point.shapeId.isEmpty) {
        continue;
      }

      if (point.lat == 0 && point.lng == 0) {
        continue;
      }

      points.add(point);
    }

    _cachedShapePoints = points;

    return points;
  }





  Future<String?> findShapeIdForTrip(
    String tripId,
  ) async {
    final trips = await fetchTrips();

    for (final trip in trips) {
      if (trip.tripId == tripId) {
        return trip.shapeId;
      }
    }

    return null;
  }



  Future<String?> findTripIdForStop(String stopId) async {
    if (_tripIdByStopId.containsKey(stopId)) {
      return _tripIdByStopId[stopId];
    }

    final archive = await _getArchive();
    final rows = await _parseCsvFile(archive, 'stop_times.txt');
    for (final row in rows) {
      if (row['stop_id']?.toString().trim() == stopId) {
        final tripId = row['trip_id']?.toString().trim();
        _tripIdByStopId[stopId] =
            tripId == null || tripId.isEmpty ? null : tripId;
        return _tripIdByStopId[stopId];
      }
    }

    _tripIdByStopId[stopId] = null;
    return null;
  }



  Future<Set<String>> findRouteIdsForStop(String stopId) async {
    if (_routeIdsByStopId == null) {
      final trips = await fetchTrips();
      final routeByTrip = {for (final trip in trips) trip.tripId: trip.routeId};
      final archive = await _getArchive();
      final rows = await _parseCsvFile(archive, 'stop_times.txt');
      final index = <String, Set<String>>{};
      for (final row in rows) {
        final id = row['stop_id']?.toString().trim() ?? '';
        final tripId = row['trip_id']?.toString().trim() ?? '';
        final routeId = routeByTrip[tripId];
        if (id.isNotEmpty && routeId != null && routeId.isNotEmpty) {
          index.putIfAbsent(id, () => <String>{}).add(routeId);
        }
      }
      _routeIdsByStopId = index;
    }
    return _routeIdsByStopId![stopId] ?? <String>{};
  }




  Future<List<String>> findStopIdsForRoute(String routeId) async {
    if (_stopIdsByRouteId == null) {
      final trips = await fetchTrips();
      final routeByTrip = {for (final trip in trips) trip.tripId: trip.routeId};
      final archive = await _getArchive();
      final rows = await _parseCsvFile(archive, 'stop_times.txt');
      final index = <String, List<MapEntry<int, String>>>{};
      for (final row in rows) {
        final tripId = row['trip_id']?.toString().trim() ?? '';
        final id = row['stop_id']?.toString().trim() ?? '';
        final routeId = routeByTrip[tripId];
        if (id.isEmpty || routeId == null || routeId.isEmpty) continue;

        final sequence =
            int.tryParse(row['stop_sequence']?.toString().trim() ?? '') ?? 0;
        index
            .putIfAbsent(routeId, () => <MapEntry<int, String>>[])
            .add(MapEntry(sequence, id));
      }

      _stopIdsByRouteId = {
        for (final entry in index.entries)
          entry.key: _uniqueStopIdsInOrder(entry.value),
      };
    }

    return _stopIdsByRouteId![routeId] ?? const <String>[];
  }

  List<String> _uniqueStopIdsInOrder(List<MapEntry<int, String>> entries) {
    entries.sort((a, b) => a.key.compareTo(b.key));
    final seen = <String>{};
    final ordered = <String>[];
    for (final entry in entries) {
      if (seen.add(entry.value)) {
        ordered.add(entry.value);
      }
    }
    return ordered;
  }






  Future<List<String>> getOrderedStopIdsForTrip(String tripId) async {
    if (_orderedStopIdsByTrip == null) {
      _stopSequenceIndexFuture ??= _buildStopSequenceIndex();
      try {
        await _stopSequenceIndexFuture;
      } catch (_) {
        _stopSequenceIndexFuture = null;
        rethrow;
      }
    }

    return _orderedStopIdsByTrip![tripId] ?? const <String>[];
  }

  Future<void> _buildStopSequenceIndex() async {
    final archive = await _getArchive();
    final rows = await _parseCsvFile(archive, 'stop_times.txt');

    final entriesByTrip = <String, List<MapEntry<int, String>>>{};

    for (final row in rows) {
      final rowTripId = row['trip_id']?.toString().trim() ?? '';
      if (rowTripId.isEmpty) continue;

      final stopId = row['stop_id']?.toString().trim() ?? '';
      if (stopId.isEmpty) {
        continue;
      }

      final sequence =
          int.tryParse(row['stop_sequence']?.toString().trim() ?? '') ?? 0;

      entriesByTrip
          .putIfAbsent(rowTripId, () => <MapEntry<int, String>>[])
          .add(MapEntry(sequence, stopId));
    }

    _orderedStopIdsByTrip = {
      for (final entry in entriesByTrip.entries)
        entry.key: (entry.value..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => e.value)
            .toList(),
    };
  }





  Future<List<ShapePoint>> fetchShapeForId(
    String shapeId,
  ) async {
    final allPoints = await fetchShapePoints();

    final routePoints = allPoints
        .where(
          (point) => point.shapeId == shapeId,
        )
        .toList();

    routePoints.sort(
      (a, b) => a.sequence.compareTo(
        b.sequence,
      ),
    );

    return routePoints;
  }





  void clearCache() {
    _cachedArchive = null;
    _cachedTrips = null;
    _cachedShapePoints = null;
    _tripIdByStopId.clear();
    _routeIdsByStopId = null;
    _stopIdsByRouteId = null;
    _orderedStopIdsByTrip = null;
    _stopSequenceIndexFuture = null;
  }
}
