import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/stop.dart';

/// Downloads the GTFS-Static feed (a ZIP of CSV files: stops.txt,
/// routes.txt, trips.txt, etc.) and extracts what we need.
///
/// We parse `stops.txt` (for the map/search) and `routes.txt` (for
/// human-readable bus numbers in the ETA list). `trips.txt` /
/// `stop_times.txt` are much larger and only needed if you build proper
/// schedule-based routing later — see README for notes on extending this.
class GtfsStaticService {
  /// Caches the decoded archive for the lifetime of one sync, so we don't
  /// download the ZIP twice when fetching both stops and routes.
  Archive? _cachedArchive;

  Future<Archive> _getArchive() async {
    if (_cachedArchive != null) return _cachedArchive!;

    final response = await http.get(Uri.parse(AppConstants.gtfsStaticUrl));
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to download GTFS-Static feed: HTTP ${response.statusCode}');
    }

    final Uint8List bytes = response.bodyBytes;
    _cachedArchive = ZipDecoder().decodeBytes(bytes);
    return _cachedArchive!;
  }

  List<Map<String, dynamic>> _parseCsvFile(Archive archive, String fileName) {
    final file = archive.files.firstWhere(
      (f) => f.name.toLowerCase().endsWith(fileName),
      orElse: () => throw Exception('$fileName not found in GTFS feed'),
    );

    final content = utf8.decode(file.content as List<int>);
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final parsed = <Map<String, dynamic>>[];

    for (final row in rows.skip(1)) {
      if (row.length != headers.length) continue; // skip malformed rows
      parsed.add({
        for (var i = 0; i < headers.length; i++) headers[i]: row[i],
      });
    }

    return parsed;
  }

  Future<List<Stop>> fetchStops() async {
    final archive = await _getArchive();
    final rows = _parseCsvFile(archive, 'stops.txt');

    final stops = <Stop>[];
    for (final row in rows) {
      final stop = Stop.fromCsvRow(row);
      if (stop.stopId.isNotEmpty) stops.add(stop);
    }
    return stops;
  }

  Future<List<TransitRoute>> fetchRoutes() async {
    final archive = await _getArchive();
    final rows = _parseCsvFile(archive, 'routes.txt');

    final routes = <TransitRoute>[];
    for (final row in rows) {
      final route = TransitRoute.fromCsvRow(row);
      if (route.routeId.isNotEmpty) routes.add(route);
    }
    return routes;
  }

  /// Call after fetching both stops and routes so the next sync
  /// re-downloads the ZIP instead of reusing a stale copy.
  void clearCache() => _cachedArchive = null;
}
