import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stop.dart';
import '../models/vehicle_eta.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';

/// Shows live ETAs for a single stop. Reached by tapping a stop from
/// Search or Favourites.
///
/// The ETA list rebuilds every time TransitProvider gets fresh vehicle
/// positions (every ~20s, see AppConstants.realtimePollInterval), so this
/// screen updates itself automatically — no manual refresh needed.
class StopDetailScreen extends StatelessWidget {
  final Stop stop;

  const StopDetailScreen({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();
    final favourites = context.watch<FavouritesProvider>();
    final etas = transit.etasForStop(stop);
    final isFav = favourites.isFavourite(stop.stopId);

    return Scaffold(
      appBar: AppBar(
        title: Text(stop.name),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border,
                color: isFav ? Colors.amber : null),
            onPressed: () =>
                context.read<FavouritesProvider>().toggleFavourite(stop),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ETA is estimated from live bus location, not an '
                    'official schedule prediction.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: etas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No buses currently tracked near this stop.\n'
                        'Try again shortly — the live feed refreshes every '
                        '20 seconds.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: etas.length,
                    itemBuilder: (context, index) =>
                        _EtaTile(eta: etas[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EtaTile extends StatelessWidget {
  final VehicleEta eta;

  const _EtaTile({required this.eta});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.directions_bus_filled_rounded),
        ),
        title: Text('Bus ${eta.routeLabel}'),
        subtitle: Text(eta.distanceLabel),
        trailing: Text(
          eta.etaLabel,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
