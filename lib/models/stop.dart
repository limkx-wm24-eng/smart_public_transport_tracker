/// Represents a single row from GTFS Static `stops.txt`.
class Stop {
  final String stopId;
  final String name;
  final double lat;
  final double lng;

  const Stop({
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lng,
  });

  /// Build from a parsed CSV row (as a Map keyed by header name).
  factory Stop.fromCsvRow(Map<String, dynamic> row) {
    return Stop(
      stopId: (row['stop_id'] ?? '').toString(),
      name: (row['stop_name'] ?? 'Unnamed stop').toString(),
      lat: double.tryParse((row['stop_lat'] ?? '0').toString()) ?? 0,
      lng: double.tryParse((row['stop_lon'] ?? '0').toString()) ?? 0,
    );
  }

  /// Build from a SQLite row.
  factory Stop.fromMap(Map<String, dynamic> map) {
    return Stop(
      stopId: map['stop_id'] as String,
      name: map['name'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stop_id': stopId,
      'name': name,
      'lat': lat,
      'lng': lng,
    };
  }
}
