import 'package:flutter/material.dart';

import '../services/google_transit_service.dart';

class GoogleRouteDetailScreen extends StatelessWidget {
  const GoogleRouteDetailScreen({super.key, required this.route});

  final GoogleTransitRoute route;

  @override
  Widget build(BuildContext context) {
    final stages = _stages(route.steps);
    return Scaffold(
      appBar: AppBar(title: const Text('Directions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.route_outlined, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(route.duration, style: Theme.of(context).textTheme.headlineSmall), const Text('Estimated journey time')])), if (route.fare != null) Text(route.fare!)]))),
          const SizedBox(height: 16),
          Text('How to get there', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...stages.indexed.map((entry) => _StageCard(number: entry.$1 + 1, stage: entry.$2)),
        ],
      ),
    );
  }

  List<_JourneyStage> _stages(List<GoogleTransitStep> steps) {
    final stages = <_JourneyStage>[];
    var index = 0;
    while (index < steps.length) {
      if (steps[index].isTransit) {
        stages.add(_JourneyStage.transit(steps[index++]));
        continue;
      }
      final walking = <GoogleTransitStep>[];
      while (index < steps.length && !steps[index].isTransit) {
        walking.add(steps[index++]);
      }
      stages.add(_JourneyStage.walk(
        duration: _duration(walking),
        distance: _distance(walking),
        destination: index < steps.length ? steps[index].departureStop ?? 'the next stop' : 'your destination',
      ));
    }
    return stages;
  }

  String _duration(List<GoogleTransitStep> steps) {
    final minutes = steps.fold<int>(0, (total, step) => total + (int.tryParse(RegExp(r'\d+').firstMatch(step.duration)?.group(0) ?? '') ?? 0));
    return minutes == 0 ? 'a few minutes' : '$minutes min';
  }

  String _distance(List<GoogleTransitStep> steps) {
    final metres = steps.fold<double>(0, (total, step) {
      final match = RegExp(r'([\d.]+)\s*(km|m)').firstMatch(step.distance);
      if (match == null) return total;
      final value = double.tryParse(match.group(1)!) ?? 0;
      return total + (match.group(2) == 'km' ? value * 1000 : value);
    });
    if (metres == 0) return '';
    return metres >= 1000 ? '${(metres / 1000).toStringAsFixed(1)} km' : '${metres.round()} m';
  }
}

class _JourneyStage {
  const _JourneyStage.walk({required this.duration, required this.distance, required this.destination}) : transit = null;
  const _JourneyStage.transit(this.transit) : duration = null, distance = null, destination = null;
  final GoogleTransitStep? transit;
  final String? duration;
  final String? distance;
  final String? destination;
  bool get isTransit => transit != null;
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.number, required this.stage});
  final int number;
  final _JourneyStage stage;

  @override
  Widget build(BuildContext context) {
    final transit = stage.transit;
    final title = stage.isTransit ? 'Take ${transit!.displayLine}${transit.headsign == null ? '' : ' toward ${transit.headsign}'}' : 'Walk to ${stage.destination}';
    final details = transit == null
        ? <String>[
            if (stage.duration != null) '${stage.duration} walk',
            if (stage.distance?.isNotEmpty ?? false) stage.distance!,
          ]
        : <String>[
            if (transit.departureStop != null)
              'Board at ${transit.departureStop}',
            if (transit.departureTime != null)
              'Leaves ${transit.departureTime}',
            if (transit.arrivalStop != null)
              'Get off at ${transit.arrivalStop}',
            if (transit.arrivalTime != null)
              'Arrives ${transit.arrivalTime}',
            if (transit.duration.isNotEmpty) 'Ride: ${transit.duration}',
          ];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(child: Text('$number')), const SizedBox(width: 12), Icon(stage.isTransit ? Icons.directions_transit : Icons.directions_walk, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(details.join('\n'))]))])));
  }
}
