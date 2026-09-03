import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_transport_plan.dart';
import 'route_planner_service.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.id,
    required this.name,
    required this.address,
    required this.coordinate,
  });

  final String id;
  final String name;
  final String address;
  final LatLng coordinate;
}

class GoogleTransitRoute {
  const GoogleTransitRoute({
    required this.duration,
    required this.fare,
    required this.steps,
  });

  final String duration;
  final String? fare;
  final List<GoogleTransitStep> steps;

  int get transfers => steps.where((step) => step.isTransit).length - 1;
}

class GoogleTransitStep {
  const GoogleTransitStep({
    required this.travelMode,
    required this.duration,
    required this.instruction,
    this.line,
    this.headsign,
  });

  final String travelMode;
  final String duration;
  final String instruction;
  final String? line;
  final String? headsign;

  bool get isTransit => travelMode == 'TRANSIT';
}

class GoogleTransitService {
  GoogleTransitService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final response = await _client.functions.invoke(
      'transit-planner',
      body: {'action': 'searchPlaces', 'query': query},
    );
    final data = _map(response.data);
    final places = data['places'];
    if (places is! List) return [];
    return places.whereType<Map>().map((item) {
      final latitude = (item['latitude'] as num?)?.toDouble();
      final longitude = (item['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) return null;
      return PlaceSearchResult(
        id: item['id']?.toString() ?? '',
        name: item['name']?.toString() ?? 'Unnamed place',
        address: item['address']?.toString() ?? '',
        coordinate: LatLng(latitude, longitude),
      );
    }).whereType<PlaceSearchResult>().toList();
  }

  Future<List<GoogleTransitRoute>> findTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    required RouteSortPreference preference,
  }) async {
    final response = await _client.functions.invoke(
      'transit-planner',
      body: {
        'action': 'findTransitRoutes',
        'origin': {'latitude': origin.latitude, 'longitude': origin.longitude},
        'destination': {'latitude': destination.latitude, 'longitude': destination.longitude},
        'preference': preference.name,
      },
    );
    final data = _map(response.data);
    final routes = data['routes'];
    if (routes is! List) return [];
    return routes.whereType<Map>().map(_routeFromJson).toList();
  }

  GoogleTransitRoute _routeFromJson(Map route) {
    final localized = route['localizedValues'] as Map?;
    final duration = localized?['duration']?['text']?.toString() ?? route['duration']?.toString() ?? 'Duration unavailable';
    final fare = localized?['transitFare']?['text']?.toString();
    final legs = route['legs'];
    final steps = <GoogleTransitStep>[];
    if (legs is List) {
      for (final leg in legs.whereType<Map>()) {
        final rawSteps = leg['steps'];
        if (rawSteps is! List) continue;
        for (final rawStep in rawSteps.whereType<Map>()) {
          final details = rawStep['transitDetails'] as Map?;
          final line = details?['transitLine'] as Map?;
          final vehicle = line?['vehicle'] as Map?;
          final local = rawStep['localizedValues'] as Map?;
          final mode = rawStep['travelMode']?.toString() ?? 'WALK';
          final instruction = rawStep['navigationInstruction']?['instructions']?.toString() ??
              (mode == 'TRANSIT' ? 'Take public transport' : 'Walk');
          steps.add(GoogleTransitStep(
            travelMode: mode,
            duration: local?['duration']?['text']?.toString() ?? '',
            instruction: instruction,
            line: line?['nameShort']?.toString() ?? line?['name']?.toString() ?? vehicle?['name']?.toString(),
            headsign: details?['headsign']?.toString(),
          ));
        }
      }
    }
    return GoogleTransitRoute(duration: duration, fare: fare, steps: steps);
  }

  Map _map(dynamic value) => value is Map ? value : const {};
}
