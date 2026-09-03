import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/eta_utils.dart';
import '../models/stop.dart';
import '../models/vehicle_position.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import 'ai_eta_screen.dart';

/// Shows live buses near a selected stop.
///
/// Flow:
/// Search Stop
/// -> StopDetailScreen
/// -> Select a live bus
/// -> BusLiveMapScreen
class StopDetailScreen extends StatefulWidget {
  final Stop stop;

  const StopDetailScreen({
    super.key,
    required this.stop,
  });

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  String? _routeVehicleId;
  bool _hasFittedCamera = false;
  String? _visibleBusesKey;
  final ScrollController _scrollController = ScrollController();

  Stop get stop => widget.stop;

  Future<void> _loadRouteFor(List<VehiclePosition> buses) async {
    VehiclePosition? bus;
    for (final vehicle in buses) {
      if ((vehicle.tripId ?? '').isNotEmpty) {
        bus = vehicle;
        break;
      }
    }
    if (bus == null) {
      if (_routeVehicleId == stop.stopId) {
        return;
      }
      _routeVehicleId = stop.stopId;
      final points =
          await context.read<TransitProvider>().getRouteShapeForStop(stop);
      if (mounted && _routeVehicleId == stop.stopId) {
        setState(() {
          _routePoints = points;
          _hasFittedCamera = false;
        });
      }
      return;
    }
    if (bus.vehicleId == _routeVehicleId) {
      return;
    }

    _routeVehicleId = bus.vehicleId;
    final points =
        await context.read<TransitProvider>().getRouteShapeForVehicle(bus);
    if (mounted && _routeVehicleId == bus.vehicleId) {
      setState(() {
        _routePoints = points;
        _hasFittedCamera = false;
      });
    }
  }

  void _fitMap(List<VehiclePosition> buses) {
    final busesKey =
        buses.map((bus) => '${bus.vehicleId}:${bus.lat}:${bus.lng}').join('|');
    if (busesKey != _visibleBusesKey) {
      _visibleBusesKey = busesKey;
      _hasFittedCamera = false;
    }
    if (_hasFittedCamera) {
      return;
    }
    final points = <LatLng>[
      LatLng(stop.lat, stop.lng),
      ...buses.map((bus) => LatLng(bus.lat, bus.lng)),
      ..._routePoints,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasFittedCamera) return;
      final firstPoint = points.first;
      final hasOnlyOneLocation = points.every(
        (point) =>
            point.latitude == firstPoint.latitude &&
            point.longitude == firstPoint.longitude,
      );
      if (hasOnlyOneLocation) {
        _mapController.move(firstPoint, 15);
        _hasFittedCamera = true;
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(32),
        ),
      );
      _hasFittedCamera = true;
    });
  }

  void _focusBus(VehiclePosition bus) {
    _mapController.move(LatLng(bus.lat, bus.lng), 16);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  List<Marker> _routeDirectionMarkers() {
    if (_routePoints.length < 2) {
      return [];
    }

    // Keep the route direction clear without covering the map with arrows.
    final step = math.max(1, (_routePoints.length / 8).ceil());
    final markers = <Marker>[];
    for (var index = step; index < _routePoints.length; index += step) {
      final previous = _routePoints[index - 1];
      final current = _routePoints[index];
      final angle = -math.atan2(
        current.latitude - previous.latitude,
        current.longitude - previous.longitude,
      );
      markers.add(
        Marker(
          point: current,
          width: 24,
          height: 24,
          child: Transform.rotate(
            angle: angle,
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.blue,
              size: 22,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();

    final favourites = context.watch<FavouritesProvider>();

    final isFav = favourites.isFavourite(stop.stopId);

    final nearbyBuses = transit.vehiclesNearStop(
      stop,
      radiusKm: 1.0,
    );
    VehiclePosition? routeBus;
    for (final bus in nearbyBuses) {
      if (bus.vehicleId == _routeVehicleId) {
        routeBus = bus;
        break;
      }
    }

    _loadRouteFor(nearbyBuses);
    _fitMap(nearbyBuses);

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
              await context.read<TransitProvider>().refreshVehicles();
            },
          ),

          // Favourite
          IconButton(
            tooltip: 'Favourite stop',
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            onPressed: () {
              context.read<FavouritesProvider>().toggleFavourite(stop);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return context.read<TransitProvider>().refreshVehicles();
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // =================================================
            // LIVE STOP MAP
            // =================================================
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(stop.lat, stop.lng),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.smart_public_transport_tracker',
                        ),
                        if (_routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            ..._routeDirectionMarkers(),
                            Marker(
                              point: LatLng(stop.lat, stop.lng),
                              width: 48,
                              height: 48,
                              child: const Icon(Icons.location_on,
                                  color: Colors.red, size: 42),
                            ),
                            ...nearbyBuses.map((bus) => Marker(
                                  point: LatLng(bus.lat, bus.lng),
                                  width: 52,
                                  height: 52,
                                  child: GestureDetector(
                                    onTap: () => _showBusDetails(context, bus),
                                    child: Transform.rotate(
                                      angle: (bus.bearing ?? 0) *
                                          3.141592653589793 /
                                          180,
                                      child: Icon(
                                        Icons.directions_bus_filled,
                                        color:
                                            bus.vehicleId == routeBus?.vehicleId
                                                ? Colors.blueAccent
                                                : Colors.deepOrange,
                                        size:
                                            bus.vehicleId == routeBus?.vehicleId
                                                ? 44
                                                : 38,
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: () => context
                          .read<FavouritesProvider>()
                          .toggleFavourite(stop),
                      icon: Icon(isFav ? Icons.star : Icons.star_border),
                      label: const Text('Favourite stop'),
                    ),
                  ),
                  if (routeBus?.routeId?.isNotEmpty ?? false)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Chip(
                        label: Text('Bus ${context.read<TransitProvider>().displayRouteLabel(routeBus!.routeId)} direction'),
                        avatar: const Icon(Icons.route, size: 18),
                      ),
                    )
                  else if (_routePoints.isNotEmpty)
                    const Positioned(
                      left: 12,
                      top: 12,
                      child: Chip(
                        label: Text('Scheduled route direction'),
                        avatar: Icon(Icons.route, size: 18),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // =================================================
            // STOP INFORMATION
            // =================================================

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icons.directions_bus_filled_rounded,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  'Live buses nearby '
                  '(${nearbyBuses.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(
              height: 5,
            ),

            const Text(
              'Currently showing buses within 1 km.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            if (nearbyBuses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AiEtaScreen(initialStop: stop),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Plan trip from here'),
                ),
              ),

            const SizedBox(
              height: 14,
            ),

            // =================================================
            // INITIAL LOADING
            // =================================================

            if (transit.vehiclesStatus == LoadStatus.loading &&
                transit.vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // =================================================
            // NO BUS FOUND
            // =================================================

            if (transit.vehiclesStatus != LoadStatus.loading &&
                nearbyBuses.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.directions_bus_outlined,
                        size: 55,
                        color: Colors.grey,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      const Text(
                        'No live buses nearby',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      const Text(
                        'No live bus is currently '
                        'within 1 km of this stop.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await context
                              .read<TransitProvider>()
                              .refreshVehicles();
                        },
                        icon: const Icon(
                          Icons.refresh,
                        ),
                        label: const Text(
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
                final distance = transit.distanceToVehicle(
                  stop,
                  bus,
                );

                return _LiveBusTile(
                  bus: bus,
                  stop: stop,
                  distanceMeters: distance,
                  onTap: () {
                    debugPrint(
                      'CLICKED BUS: '
                      '${bus.vehicleId}',
                    );

                    _focusBus(bus);
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

  void _showBusDetails(BuildContext context, VehiclePosition bus) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehicle: ${bus.vehicleId}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Bus: ${context.read<TransitProvider>().displayRouteLabel(bus.routeId)}'),
            Text('Trip: ${bus.tripId ?? 'Unknown'}'),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIVE BUS TILE
// ============================================================

class _LiveBusTile extends StatelessWidget {
  final VehiclePosition bus;
  final Stop stop;
  final double distanceMeters;

  final VoidCallback onTap;

  const _LiveBusTile({
    required this.bus,
    required this.stop,
    required this.distanceMeters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(
            Icons.directions_bus_filled_rounded,
          ),
        ),
        title: Text(
          bus.routeId != null && bus.routeId!.isNotEmpty
              ? 'Bus ${context.read<TransitProvider>().displayRouteLabel(bus.routeId)}'
              : 'Live Bus',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiEtaScreen(initialStop: stop),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text(
                  'Plan trip',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              estimateEtaLabel(distanceMeters),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
            ),
          ],
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

    final km = meters / 1000;

    return '${km.toStringAsFixed(2)} km away';
  }
}
