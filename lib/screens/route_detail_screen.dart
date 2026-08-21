import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/route_model.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import '../services/location_service.dart';

/// Shows live vehicles currently running on a bus line. Reached by
/// tapping a route from Search or Favourites.
class RouteDetailScreen extends StatefulWidget {
  final TransitRoute route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final LocationService _locationService = LocationService();
  Position? _myLocation;

  @override
  void initState() {
    super.initState();
    _locationService.getCurrentPosition().then((pos) {
      if (mounted) setState(() => _myLocation = pos);
    });
  }

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();
    final favourites = context.watch<FavouritesProvider>();
    final vehicles = transit.vehiclesForRoute(widget.route.routeId);
    final isFav = favourites.isFavourite(widget.route.routeId);

    // Sort by distance from the user when we have a GPS fix, otherwise
    // just show them in whatever order the feed returned.
    final sortedVehicles = [...vehicles];
    if (_myLocation != null) {
      sortedVehicles.sort((a, b) {
        final da = Geolocator.distanceBetween(
            _myLocation!.latitude, _myLocation!.longitude, a.lat, a.lng);
        final db = Geolocator.distanceBetween(
            _myLocation!.latitude, _myLocation!.longitude, b.lat, b.lng);
        return da.compareTo(db);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.route.displayLabel}'),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border,
                color: isFav ? Colors.amber : null),
            onPressed: () => context
                .read<FavouritesProvider>()
                .toggleFavourite(widget.route),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.route.longName.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(widget.route.longName,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${vehicles.length} bus${vehicles.length == 1 ? '' : 'es'} running now',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: vehicles.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No live buses currently tracked on this line.\n'
                      'The feed refreshes every 20 seconds — try again '
                      'shortly.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : ListView.builder(
              itemCount: sortedVehicles.length,
              itemBuilder: (context, index) {
                final v = sortedVehicles[index];
                String? distanceLabel;
                if (_myLocation != null) {
                  final d = Geolocator.distanceBetween(
                    _myLocation!.latitude,
                    _myLocation!.longitude,
                    v.lat,
                    v.lng,
                  );
                  distanceLabel = d < 1000
                      ? '${d.round()} m away'
                      : '${(d / 1000).toStringAsFixed(1)} km away';
                }
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.directions_bus_filled_rounded,
                      color: Colors.deepOrange,
                    ),
                    title: Text('Vehicle ${v.vehicleId}'),
                    subtitle: distanceLabel != null
                        ? Text(distanceLabel)
                        : Text(
                        '${v.lat.toStringAsFixed(4)}, ${v.lng.toStringAsFixed(4)}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}