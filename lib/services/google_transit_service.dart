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
    required this.durationSeconds,
    required this.fare,
    required this.steps,
  });

  final String duration;
  final int durationSeconds;
  final String? fare;
  final List<GoogleTransitStep> steps;

  int get transfers => steps.where((step) => step.isTransit).length - 1;

  GoogleTransitRoute withPassengerLabels(String? Function(String?) lookup) =>
      GoogleTransitRoute(
        duration: duration,
        durationSeconds: durationSeconds,
        fare: fare,
        steps: steps.map((step) => step.withPassengerLabel(lookup(step.line))).toList(),
      );
}

class GoogleTransitStep {
  const GoogleTransitStep({
    required this.travelMode,
    required this.duration,
    required this.distance,
    required this.instruction,
    this.line,
    this.lineName,
    this.vehicleType,
    this.passengerLabel,
    this.headsign,
    this.departureStop,
    this.arrivalStop,
    this.departureTime,
    this.arrivalTime,
  });

  final String travelMode;
  final String duration;
  final String distance;
  final String instruction;
  final String? line;
  final String? lineName;
  final String? vehicleType;
  final String? passengerLabel;
  final String? headsign;
  final String? departureStop;
  final String? arrivalStop;
  final String? departureTime;
  final String? arrivalTime;

  bool get isTransit => travelMode == 'TRANSIT';

  GoogleTransitStep withPassengerLabel(String? label) => GoogleTransitStep(
        travelMode: travelMode,
        duration: duration,
        distance: distance,
        instruction: instruction,
        line: line,
        lineName: lineName,
        vehicleType: vehicleType,
        passengerLabel: label,
        headsign: headsign,
        departureStop: departureStop,
        arrivalStop: arrivalStop,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
      );

  String get displayLine {
    if (passengerLabel != null && passengerLabel!.isNotEmpty) {
      return passengerLabel!;
    }
    final name = lineName?.trim() ?? line?.trim() ?? 'Public transport';
    if (vehicleType == 'BUS' || vehicleType == 'INTERCITY_BUS') {
      return line?.trim() ?? 'Bus';
    }
    final normalized = name.toLowerCase();
    if (vehicleType == 'MONORAIL') return 'KL Monorail $name';
    if (vehicleType == 'COMMUTER_TRAIN') return 'KTM Komuter $name';
    if (normalized.contains('kelana jaya') ||
        normalized.contains('ampang') ||
        normalized.contains('sri petaling')) {
      return 'LRT $name';
    }
    if (normalized.contains('kajang') || normalized.contains('putrajaya')) {
      return 'MRT $name';
    }
    if (vehicleType == 'METRO_RAIL' ||
        vehicleType == 'SUBWAY' ||
        vehicleType == 'TRAM') {
      return 'LRT $name';
    }
    return name;
  }
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
    final parsed = routes.whereType<Map>().map(_routeFromJson).toList()
      ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    return parsed;
  }

  GoogleTransitRoute _routeFromJson(Map route) {
    final localized = route['localizedValues'] as Map?;
    final duration = localized?['duration']?['text']?.toString() ?? route['duration']?.toString() ?? 'Duration unavailable';
    final durationSeconds = int.tryParse(
          RegExp(r'\d+').firstMatch(route['duration']?.toString() ?? '')?.group(0) ?? '',
        ) ??
        0;
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
          final stopDetails = details?['stopDetails'] as Map?;
          final transitLocal = details?['localizedValues'] as Map?;
          final local = rawStep['localizedValues'] as Map?;
          final mode = rawStep['travelMode']?.toString() ?? 'WALK';
          final instruction = rawStep['navigationInstruction']?['instructions']?.toString() ??
              (mode == 'TRANSIT' ? 'Take public transport' : 'Walk');
          steps.add(GoogleTransitStep(
            travelMode: mode,
            duration: local?['duration']?['text']?.toString() ??
                local?['staticDuration']?['text']?.toString() ??
                '',
            distance: local?['distance']?['text']?.toString() ?? '',
            instruction: instruction,
            line: line?['nameShort']?.toString() ?? line?['name']?.toString() ?? vehicle?['name']?.toString(),
            lineName: line?['name']?.toString(),
            vehicleType: vehicle?['type']?.toString(),
            headsign: details?['headsign']?.toString(),
            departureStop: stopDetails?['departureStop']?['name']?.toString(),
            arrivalStop: stopDetails?['arrivalStop']?['name']?.toString(),
            departureTime: transitLocal?['departureTime']?['time']?['text']?.toString(),
            arrivalTime: transitLocal?['arrivalTime']?['time']?['text']?.toString(),
          ));
        }
      }
    }
    return GoogleTransitRoute(
      duration: duration,
      durationSeconds: durationSeconds,
      fare: fare,
      steps: steps,
    );
  }

  Map _map(dynamic value) => value is Map ? value : const {};
}
