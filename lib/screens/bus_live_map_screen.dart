import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/eta_utils.dart';
import '../models/stop.dart';
import '../models/vehicle_position.dart';
import '../providers/transit_provider.dart';

class BusLiveMapScreen extends StatefulWidget {
  final Stop stop;
  final VehiclePosition vehicle;

  const BusLiveMapScreen({
    super.key,
    required this.stop,
    required this.vehicle,
  });

  @override
  State<BusLiveMapScreen> createState() =>
      _BusLiveMapScreenState();
}

class _BusLiveMapScreenState
    extends State<BusLiveMapScreen> {
  final MapController _mapController =
  MapController();

  List<LatLng> _routePoints = [];

  bool _isLoadingRoute = true;

  String? _routeError;



  bool _hasFittedRoute = false;





  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        _loadActualRoute();
      },
    );
  }





  Future<void> _loadActualRoute() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    final transit =
    context.read<TransitProvider>();


    final latestBus =
        transit.findVehicleById(
          widget.vehicle.vehicleId,
        ) ??
            widget.vehicle;

    debugPrint(
      '================================',
    );

    debugPrint(
      'BusLiveMapScreen loading route',
    );

    debugPrint(
      'Vehicle ID: ${latestBus.vehicleId}',
    );

    debugPrint(
      'Route ID: ${latestBus.routeId}',
    );

    debugPrint(
      'Trip ID: ${latestBus.tripId}',
    );













    if (latestBus.tripId == null ||
        latestBus.tripId!.isEmpty) {
      debugPrint(
        'Cannot display route because '
            'tripId is missing.',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = [];

        _isLoadingRoute = false;

        _routeError =
        'This live bus does not provide '
            'a trip ID, so its route cannot '
            'be displayed.';
      });

      return;
    }

    try {
      final points =
      await transit
          .getRouteShapeForVehicle(
        latestBus,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = points;

        _isLoadingRoute = false;

        if (points.isEmpty) {
          _routeError =
          'No GTFS route shape was found '
              'for this bus.';
        } else {
          _routeError = null;
        }
      });

      debugPrint(
        'BusLiveMapScreen received '
            '${points.length} route points.',
      );


      if (points.isNotEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback(
              (_) {
            _fitRouteToScreen();
          },
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'BusLiveMapScreen route error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = [];

        _isLoadingRoute = false;

        _routeError =
        'Unable to load this bus route.';
      });
    }
  }





  void _fitRouteToScreen() {
    if (!mounted ||
        _routePoints.isEmpty) {
      return;
    }

    try {
      final points =
      List<LatLng>.from(
        _routePoints,
      );


      points.add(
        LatLng(
          widget.stop.lat,
          widget.stop.lng,
        ),
      );

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds:
          LatLngBounds.fromPoints(
            points,
          ),
          padding:
          const EdgeInsets.fromLTRB(
            40,
            80,
            40,
            250,
          ),
        ),
      );

      _hasFittedRoute = true;
    } catch (e) {
      debugPrint(
        'Unable to fit route camera: $e',
      );
    }
  }





  void _centreOnBus(
      VehiclePosition bus,
      ) {
    _mapController.move(
      LatLng(
        bus.lat,
        bus.lng,
      ),
      16,
    );
  }





  Future<void> _refreshBus() async {
    final transit =
    context.read<TransitProvider>();

    await transit.refreshVehicles();

    if (!mounted) {
      return;
    }

    final updatedBus =
    transit.findVehicleById(
      widget.vehicle.vehicleId,
    );

    if (updatedBus != null) {
      _centreOnBus(
        updatedBus,
      );


      if (_routePoints.isEmpty) {
        await _loadActualRoute();
      }
    }
  }





  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<TransitProvider>(
          builder: (
              context,
              transit,
              _,
              ) {
            final latestBus =
                transit.findVehicleById(
                  widget.vehicle.vehicleId,
                ) ??
                    widget.vehicle;

            return Text(
              latestBus.routeId != null &&
                  latestBus
                      .routeId!
                      .isNotEmpty
                  ? 'Bus ${transit.displayRouteLabel(latestBus.routeId)}'
                  : 'Live Bus',
            );
          },
        ),

        actions: [




          IconButton(
            tooltip: 'Show whole route',
            icon: const Icon(
              Icons.route,
            ),
            onPressed:
            _routePoints.isEmpty
                ? null
                : _fitRouteToScreen,
          ),





          IconButton(
            tooltip:
            'Refresh bus location',
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed:
            _refreshBus,
          ),
        ],
      ),

      body: Consumer<TransitProvider>(
        builder: (
            context,
            transit,
            _,
            ) {




          final latestBus =
              transit.findVehicleById(
                widget.vehicle.vehicleId,
              ) ??
                  widget.vehicle;

          final busLocation =
          LatLng(
            latestBus.lat,
            latestBus.lng,
          );

          final stopLocation =
          LatLng(
            widget.stop.lat,
            widget.stop.lng,
          );





          final distanceMeters =
          transit.distanceToVehicle(
            widget.stop,
            latestBus,
          );

          String distanceText;

          if (distanceMeters < 1000) {
            distanceText =
            '${distanceMeters.toStringAsFixed(0)} m';
          } else {
            distanceText =
            '${(distanceMeters / 1000).toStringAsFixed(2)} km';
          }





          return Stack(
            children: [
              FlutterMap(
                mapController:
                _mapController,

                options: MapOptions(
                  initialCenter:
                  busLocation,

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
                          points:
                          _routePoints,

                          strokeWidth: 5,

                          color:
                          Colors.blue,
                        ),
                      ],
                    ),





                  MarkerLayer(
                    markers: [




                      Marker(
                        point:
                        stopLocation,

                        width: 55,
                        height: 55,

                        child:
                        const Icon(
                          Icons.location_on,
                          color:
                          Colors.red,
                          size: 44,
                        ),
                      ),





                      Marker(
                        point:
                        busLocation,

                        width: 60,
                        height: 60,

                        child:
                        Transform.rotate(
                          angle:
                          latestBus
                              .bearing !=
                              null
                              ? latestBus
                              .bearing! *
                              3.141592653589793 /
                              180
                              : 0,

                          child:
                          const Icon(
                            Icons
                                .directions_bus_filled,
                            color: Colors
                                .deepOrange,
                            size: 45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),





              Positioned(
                top: 12,
                left: 12,

                child: Chip(
                  avatar:
                  const Icon(
                    Icons.circle,
                    size: 12,
                    color:
                    Colors.green,
                  ),

                  label:
                  const Text(
                    'Live',
                  ),
                ),
              ),





              if (_isLoadingRoute)
                Positioned(
                  top: 12,
                  right: 12,

                  child: Card(
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),

                      child: Row(
                        mainAxisSize:
                        MainAxisSize.min,

                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,

                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          const Text(
                            'Loading route...',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),





              if (!_isLoadingRoute &&
                  _routeError != null)
                Positioned(
                  top: 65,
                  left: 12,
                  right: 12,

                  child: Card(
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .errorContainer,

                    child: Padding(
                      padding:
                      const EdgeInsets.all(
                        10,
                      ),

                      child: Text(
                        _routeError!,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          )
                              .colorScheme
                              .onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),





              Positioned(
                left: 12,
                right: 12,
                bottom: 20,

                child: Card(
                  elevation: 5,

                  child: Padding(
                    padding:
                    const EdgeInsets.all(
                      16,
                    ),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                      mainAxisSize:
                      MainAxisSize.min,

                      children: [




                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .directions_bus_filled,
                              color: Colors
                                  .deepOrange,
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Expanded(
                              child: Text(
                                latestBus.routeId !=
                                    null &&
                                    latestBus
                                        .routeId!
                                        .isNotEmpty
                                    ? 'Bus ${transit.displayRouteLabel(latestBus.routeId)}'
                                    : 'Live Bus',

                                style:
                                const TextStyle(
                                  fontSize:
                                  18,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 10,
                        ),


                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.schedule, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Estimated Time: ${estimateEtaLabel(distanceMeters)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),





                        Text(
                          'Bus ID: '
                              '${latestBus.vehicleId}',
                        ),

                        const SizedBox(
                          height: 4,
                        ),





                        Text(
                          'Selected stop: '
                              '${widget.stop.name}',
                        ),

                        const SizedBox(
                          height: 4,
                        ),





                        Text(
                          'Distance to stop: '
                              '$distanceText',
                        ),

                        const SizedBox(
                          height: 4,
                        ),





                        if (latestBus.tripId !=
                            null &&
                            latestBus
                                .tripId!
                                .isNotEmpty)
                          Text(
                            'Trip ID: '
                                '${latestBus.tripId}',
                          ),

                        const SizedBox(
                          height: 12,
                        ),





                        const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors
                                  .deepOrange,
                            ),

                            SizedBox(
                              width: 6,
                            ),

                            Text(
                              'Live location',
                              style:
                              TextStyle(
                                color:
                                Colors.green,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 8,
                        ),





                        if (_isLoadingRoute)
                          const Text(
                            'Loading actual GTFS route...',
                            style:
                            TextStyle(
                              fontSize: 12,
                              color:
                              Colors.grey,
                            ),
                          )
                        else if (_routePoints
                            .isNotEmpty)
                          Text(
                            'GTFS route loaded '
                                '(${_routePoints.length} points)',
                            style:
                            const TextStyle(
                              fontSize: 12,
                              color:
                              Colors.green,
                              fontWeight:
                              FontWeight
                                  .w500,
                            ),
                          )
                        else
                          const Text(
                            'GTFS route unavailable',
                            style:
                            TextStyle(
                              fontSize: 12,
                              color:
                              Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),





              Positioned(
                right: 16,
                bottom: 260,

                child:
                FloatingActionButton.small(
                  heroTag:
                  'centre_bus',

                  tooltip:
                  'Centre on bus',

                  onPressed: () {
                    _centreOnBus(
                      latestBus,
                    );
                  },

                  child:
                  const Icon(
                    Icons
                        .directions_bus,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
