/// A stop the user has saved for quick access (e.g. their daily commute).
/// This is Member B's module — purely local data, never fetched remotely.
class FavouriteStop {
  final String stopId;
  final String name;
  final double lat;
  final double lng;
  final DateTime savedAt;

  const FavouriteStop({
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.savedAt,
  });

  factory FavouriteStop.fromMap(Map<String, dynamic> map) {
    return FavouriteStop(
      stopId: map['stop_id'] as String,
      name: map['name'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      savedAt: DateTime.fromMillisecondsSinceEpoch(map['saved_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stop_id': stopId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'saved_at': savedAt.millisecondsSinceEpoch,
    };
  }
}
