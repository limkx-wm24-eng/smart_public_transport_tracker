import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stop.dart';
import '../models/vehicle_position.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import 'bus_live_map_screen.dart';

/// Shows live buses near a selected stop.
///
/// Flow:
/// Search Stop
/// -> StopDetailScreen
/// -> Select a live bus
/// -> BusLiveMapScreen
class StopDetailScreen extends StatelessWidget {
  final Stop stop;

  const StopDetailScreen({
    super.key,
    required this.stop,
  });

  @override
  Widget build(BuildContext context) {
    final transit =
    context.watch<TransitProvider>();

    final favourites =
    context.watch<FavouritesProvider>();

    final isFav =
    favourites.isFavourite(stop.stopId);

    // For testing, use 5 km first.
    // After confirming it works, you can change it to 1.0 km.
    final nearbyBuses =
    transit.vehiclesNearStop(
      stop,
      radiusKm: 5.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          stop.name,
        ),

        actions: [
          // Refresh live bus positions
          IconButton(
            tooltip: 'Refresh live buses',
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed: () async {
              await context
                  .read<TransitProvider>()
                  .refreshVehicles();
            },
          ),

          // Favourite
          IconButton(
            tooltip: 'Favourite stop',
            icon: Icon(
              isFav
                  ? Icons.star
                  : Icons.star_border,

              color:
              isFav
                  ? Colors.amber
                  : null,
            ),

            onPressed: () {
              context
                  .read<FavouritesProvider>()
                  .toggleFavourite(stop);
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () {
          return context
              .read<TransitProvider>()
              .refreshVehicles();
        },

        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),

          padding:
          const EdgeInsets.all(16),

          children: [
            // =================================================
            // STOP INFORMATION
            // =================================================

            Card(
              child: Padding(
                padding:
                const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 28,
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: Text(
                            stop.name,

                            style:
                            const TextStyle(
                              fontSize: 19,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Stop ID: ${stop.stopId}',
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Latitude: '
                          '${stop.lat.toStringAsFixed(6)}',
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Longitude: '
                          '${stop.lng.toStringAsFixed(6)}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // =================================================
            // INFORMATION MESSAGE
            // =================================================

            Container(
              width: double.infinity,

              padding:
              const EdgeInsets.all(14),

              decoration:
              BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,

                borderRadius:
                BorderRadius.circular(12),
              ),

              child: const Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                  ),

                  SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      'The buses below are live vehicles '
                          'currently detected near this stop. '
                          'Tap a bus to view its live location '
                          'on the map.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // =================================================
            // LIVE BUS TITLE
            // =================================================

            Row(
              children: [
                const Icon(
                  Icons
                      .directions_bus_filled_rounded,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  'Live buses nearby '
                      '(${nearbyBuses.length})',

                  style:
                  Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 5,
            ),

            const Text(
              'Currently showing buses within 5 km.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // INITIAL LOADING
            // =================================================

            if (transit.vehiclesStatus ==
                LoadStatus.loading &&
                transit.vehicles.isEmpty)
              const Padding(
                padding:
                EdgeInsets.all(30),

                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              ),

            // =================================================
            // NO BUS FOUND
            // =================================================

            if (transit.vehiclesStatus !=
                LoadStatus.loading &&
                nearbyBuses.isEmpty)
              Card(
                child: Padding(
                  padding:
                  const EdgeInsets.all(24),

                  child: Column(
                    children: [
                      const Icon(
                        Icons
                            .directions_bus_outlined,
                        size: 55,
                        color: Colors.grey,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      const Text(
                        'No live buses nearby',
                        style:
                        TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'No live bus is currently '
                            'within 5 km of this stop.',
                        textAlign:
                        TextAlign.center,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      FilledButton.icon(
                        onPressed: () async {
                          await context
                              .read<
                              TransitProvider>()
                              .refreshVehicles();
                        },

                        icon:
                        const Icon(
                          Icons.refresh,
                        ),

                        label:
                        const Text(
                          'Refresh',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // =================================================
            // LIVE BUS LIST
            // =================================================

            ...nearbyBuses.map(
                  (bus) {
                final distance =
                transit.distanceToVehicle(
                  stop,
                  bus,
                );

                return _LiveBusTile(
                  bus: bus,
                  distanceMeters:
                  distance,

                  onTap: () {
                    debugPrint(
                      'CLICKED BUS: '
                          '${bus.vehicleId}',
                    );

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            BusLiveMapScreen(
                              stop: stop,
                              vehicle: bus,
                            ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIVE BUS TILE
// ============================================================

class _LiveBusTile
    extends StatelessWidget {
  final VehiclePosition bus;

  final double distanceMeters;

  final VoidCallback onTap;

  const _LiveBusTile({
    required this.bus,
    required this.distanceMeters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),

      child: ListTile(
        onTap: onTap,

        leading: CircleAvatar(
          backgroundColor:
          Theme.of(context)
              .colorScheme
              .primaryContainer,

          child: const Icon(
            Icons
                .directions_bus_filled_rounded,
          ),
        ),

        title: Text(
          bus.routeId != null &&
              bus.routeId!.isNotEmpty
              ? 'Route ${bus.routeId}'
              : 'Live Bus',
        ),

        subtitle: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            const SizedBox(
              height: 4,
            ),

            Text(
              'Bus ID: '
                  '${bus.vehicleId}',
            ),

            const SizedBox(
              height: 2,
            ),

            Text(
              _distanceLabel(
                distanceMeters,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            const Text(
              'Tap to view live location',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),

        trailing:
        const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }

  String _distanceLabel(
      double meters,
      ) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m away';
    }

    final km =
        meters / 1000;

    return '${km.toStringAsFixed(2)} km away';
  }
}