// A bus line the user has saved for quick access (e.g. their daily
// commute route). Local-only data — never fetched from the network.
class FavouriteRoute {
  final String routeId;
  final String shortName;
  final String longName;
  final DateTime savedAt;

  const FavouriteRoute({
    required this.routeId,
    required this.shortName,
    required this.longName,
    required this.savedAt,
  });

  /// What to show in the UI — falls back sensibly if a field is missing.
  String get displayLabel => shortName.isNotEmpty ? shortName : longName;

  factory FavouriteRoute.fromMap(Map<String, dynamic> map) {
    return FavouriteRoute(
      routeId: map['route_id'] as String,
      shortName: map['short_name'] as String,
      longName: map['long_name'] as String,
      savedAt: DateTime.fromMillisecondsSinceEpoch(map['saved_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'route_id': routeId,
      'short_name': shortName,
      'long_name': longName,
      'saved_at': savedAt.millisecondsSinceEpoch,
    };
  }
}