import 'dart:typed_data';

import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart'
    as gtfsrt;
import 'package:http/http.dart' as http;









Future<void> main(List<String> arguments) async {
  const supportedCategories = {
    'rapid-bus-kl',
    'rapid-bus-mrtfeeder',
    'rapid-bus-kuantan',
    'rapid-bus-penang',
  };
  final category = arguments.isEmpty ? 'rapid-bus-kl' : arguments.first;

  if (!supportedCategories.contains(category)) {
    print('Unsupported category: $category');
    print('Use one of: ${supportedCategories.join(', ')}');
    return;
  }

  final endpoint =
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana'
      '?category=$category';

  print('Checking $category live bus feed...');
  print(endpoint);



  final response = await http
      .get(Uri.parse(endpoint))
      .timeout(const Duration(seconds: 20));

  print('HTTP status: ${response.statusCode}');
  print('Response size: ${response.bodyBytes.length} bytes');

  if (response.statusCode != 200) {
    print('Feed request failed. Try again later.');
    return;
  }

  final feed = gtfsrt.FeedMessage.fromBuffer(
    Uint8List.fromList(response.bodyBytes),
  );
  final vehicles = feed.entity
      .where((entity) => entity.hasVehicle() && entity.vehicle.hasPosition())
      .toList();

  print('GTFS entities: ${feed.entity.length}');
  print('Vehicle positions available: ${vehicles.length}');

  if (vehicles.isEmpty) {
    print(
      'RESULT: The API is online but is not currently publishing any vehicle '
      'locations for $category.',
    );
    return;
  }

  print('RESULT: Live vehicles are available for $category.');
  print('First few vehicles:');
  for (final entity in vehicles.take(5)) {
    final vehicle = entity.vehicle;
    final routeId = vehicle.hasTrip() ? vehicle.trip.routeId : 'unknown route';
    print(
      '- ${vehicle.vehicle.id.isEmpty ? entity.id : vehicle.vehicle.id} '
      '| route: $routeId '
      '| ${vehicle.position.latitude.toStringAsFixed(5)}, '
      '${vehicle.position.longitude.toStringAsFixed(5)}',
    );
  }
}
