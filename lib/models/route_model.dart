


class TransitRoute {
  final String routeId;
  final String shortName;
  final String longName;
  final int routeType;

  const TransitRoute({
    required this.routeId,
    required this.shortName,
    required this.longName,
    this.routeType = 3,
  });

  factory TransitRoute.fromCsvRow(Map<String, dynamic> row) {
    return TransitRoute(
      routeId: (row['route_id'] ?? '').toString(),
      shortName: (row['route_short_name'] ?? '').toString(),
      longName: (row['route_long_name'] ?? '').toString(),
      routeType: int.tryParse((row['route_type'] ?? '3').toString()) ?? 3,
    );
  }

  factory TransitRoute.fromMap(Map<String, dynamic> map) {
    return TransitRoute(
      routeId: map['route_id'] as String,
      shortName: map['short_name'] as String,
      longName: map['long_name'] as String,
      routeType: (map['route_type'] as int?) ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'route_id': routeId,
      'short_name': shortName,
      'long_name': longName,
      'route_type': routeType,
    };
  }



  String get displayLabel {
    if (shortName.isNotEmpty) return shortName;
    if (longName.isNotEmpty) return longName;
    return routeId;
  }




  String get passengerDisplayLabel {
    const railTypes = {0, 1, 2, 5, 6, 7, 11, 12};
    if (railTypes.contains(routeType) && longName.isNotEmpty) return longName;
    return displayLabel;
  }
}
