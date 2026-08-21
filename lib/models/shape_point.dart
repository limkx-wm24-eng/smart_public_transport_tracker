class ShapePoint {
  final String shapeId;
  final double lat;
  final double lng;
  final int sequence;

  ShapePoint({
    required this.shapeId,
    required this.lat,
    required this.lng,
    required this.sequence,
  });

  factory ShapePoint.fromCsvRow(
      Map<String, dynamic> row,
      ) {
    return ShapePoint(
      shapeId:
      row['shape_id']?.toString().trim() ?? '',

      lat: double.tryParse(
        row['shape_pt_lat']?.toString() ?? '',
      ) ??
          0,

      lng: double.tryParse(
        row['shape_pt_lon']?.toString() ?? '',
      ) ??
          0,

      sequence: int.tryParse(
        row['shape_pt_sequence']
            ?.toString() ??
            '',
      ) ??
          0,
    );
  }
}