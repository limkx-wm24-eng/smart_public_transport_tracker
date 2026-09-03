import 'package:flutter/material.dart';

import '../models/public_transport_plan.dart';

class RouteDetailScreen extends StatelessWidget {
  const RouteDetailScreen({
    super.key,
    required this.plan,
    this.aiAdvice,
  });

  final PublicTransportPlan plan;
  final String? aiAdvice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan.totalDurationMinutes} min',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Arrival ${_formatTime(plan.arrivalTime)}'),
                  Text(
                    plan.estimatedFare == null
                        ? 'Fare unavailable'
                        : 'Estimated fare RM${plan.estimatedFare!.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...plan.legs.map((leg) => _LegTile(leg: leg)),
          if (aiAdvice != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome),
                    const SizedBox(width: 10),
                    Expanded(child: Text(aiAdvice!)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _LegTile extends StatelessWidget {
  const _LegTile({required this.leg});

  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final title = switch (leg.type) {
      LegType.walking => 'Walk ${leg.distanceMetres.round()} m',
      LegType.bus => 'Bus ${leg.routeNumber ?? ''}'.trim(),
      LegType.train => leg.routeName ?? 'Train',
    };
    final icon = switch (leg.type) {
      LegType.walking => Icons.directions_walk,
      LegType.bus => Icons.directions_bus_filled,
      LegType.train => Icons.train,
    };

    final details = <String>[
      '${leg.durationMinutes} min',
      if (leg.realtimeEta != null) 'ETA ${leg.realtimeEta}',
      if (leg.departureTime != null)
        'Depart ${_formatTime(leg.departureTime!)}',
      if (leg.arrivalTime != null) 'Arrive ${_formatTime(leg.arrivalTime!)}',
      if (leg.stops != null) '${leg.stops} stops',
    ];

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${leg.startName}\n${leg.endName}\n${details.join(' | ')}',
          ),
          isThreeLine: true,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Icon(Icons.keyboard_arrow_down),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
