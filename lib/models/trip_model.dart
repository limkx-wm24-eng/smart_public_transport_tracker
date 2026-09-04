class TransitTrip {
  final String routeId;
  final String tripId;
  final String? shapeId;

  TransitTrip({
    required this.routeId,
    required this.tripId,
    required this.shapeId,
  });

  factory TransitTrip.fromCsvRow(
      Map<String, dynamic> row,
      ) {
    return TransitTrip(
      routeId:
      row['route_id']?.toString().trim() ?? '',
      tripId:
      row['trip_id']?.toString().trim() ?? '',
      shapeId:
      row['shape_id']?.toString().trim().isEmpty ?? true
          ? null
          : row['shape_id'].toString().trim(),
    );
  }
}
