import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/transit_provider.dart';
import '../services/location_service.dart';
import 'stop_detail_screen.dart';

/// Member A's screen — live bus locations on a map.
/// Uses OpenStreetMap tiles via flutter_map.
class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  LatLng? _myLocation;

  // =========================================================
  // SHOW ALL LIVE BUSES
  // =========================================================
  void _showAllBuses(TransitProvider transit) {
    if (transit.vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No live bus positions are available yet.',
          ),
        ),
      );

      return;
    }

    final points = transit.vehicles
        .map(
          (vehicle) => LatLng(
        vehicle.lat,
        vehicle.lng,
      ),
    )
        .toList();

    // If there is only one bus, simply zoom to it.
    if (points.length == 1) {
      _mapController.move(
        points.first,
        15,
      );

      return;
    }

    // Fit all bus positions inside the visible map.
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  // =========================================================
  // GET USER CURRENT LOCATION
  // =========================================================
  Future<void> _locateMe() async {
    try {
      final pos = await _locationService.getCurrentPosition();

      if (pos == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to get your current location. '
                  'Please enable GPS and location permission.',
            ),
          ),
        );

        return;
      }

      if (!mounted) return;

      final location = LatLng(
        pos.latitude,
        pos.longitude,
      );

      setState(() {
        _myLocation = location;
      });

      _mapController.move(
        location,
        15,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location error: $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // REFRESH LIVE BUS DATA
  // =========================================================
  Future<void> _refreshBuses(
      TransitProvider transit,
      ) async {
    try {
      await transit.refreshVehicles();

      if (!mounted) return;

      if (transit.vehicles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No live buses were returned by the GTFS feed.',
            ),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${transit.vehicles.length} live buses loaded.',
          ),
        ),
      );

      // Automatically show the buses after refreshing.
      _showAllBuses(transit);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to refresh buses: $e',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // DO NOT automatically call _locateMe().
    //
    // If you automatically move to the user's location,
    // Rapid KL buses may be outside the visible map area.
    //
    // _locateMe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // =======================================================
      // APP BAR
      // =======================================================
      appBar: AppBar(
        title: const Text(
          'Live Tracker',
        ),

        actions: [
          // SHOW ALL BUSES BUTTON
          Consumer<TransitProvider>(
            builder: (
                context,
                transit,
                _,
                ) {
              return IconButton(
                tooltip: 'Show all live buses',
                onPressed: () {
                  _showAllBuses(transit);
                },
                icon: const Icon(
                  Icons.directions_bus_filled_rounded,
                ),
              );
            },
          ),

          // REFRESH BUTTON
          Consumer<TransitProvider>(
            builder: (
                context,
                transit,
                _,
                ) {
              return IconButton(
                tooltip: 'Refresh live buses',
                onPressed:
                transit.vehiclesStatus ==
                    LoadStatus.loading
                    ? null
                    : () {
                  _refreshBuses(transit);
                },
                icon: const Icon(
                  Icons.refresh,
                ),
              );
            },
          ),

          // MY LOCATION BUTTON
          IconButton(
            tooltip: 'Centre on my location',
            onPressed: _locateMe,
            icon: const Icon(
              Icons.my_location,
            ),
          ),
        ],
      ),

      // =======================================================
      // BODY
      // =======================================================
      body: Consumer<TransitProvider>(
        builder: (
            context,
            transit,
            _,
            ) {
          return Stack(
            children: [
              // =================================================
              // MAP
              // =================================================
              FlutterMap(
                mapController: _mapController,

                options: const MapOptions(
                  initialCenter: LatLng(
                    AppConstants.defaultLat,
                    AppConstants.defaultLng,
                  ),
                  initialZoom:
                  AppConstants.defaultZoom,
                ),

                children: [
                  // =============================================
                  // OPEN STREET MAP
                  // =============================================
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                    userAgentPackageName:
                    'com.example.smart_public_transport_tracker',
                  ),

                  // =============================================
                  // MARKERS
                  // =============================================
                  MarkerLayer(
                    markers: [
                      // -----------------------------------------
                      // USER LOCATION MARKER
                      // -----------------------------------------
                      if (_myLocation != null)
                        Marker(
                          point: _myLocation!,
                          width: 45,
                          height: 45,
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),

                      // -----------------------------------------
                      // BUS STOP MARKERS
                      // -----------------------------------------
                      ...transit.stops
                          .take(300)
                          .map(
                            (stop) => Marker(
                          point: LatLng(
                            stop.lat,
                            stop.lng,
                          ),
                          width: 24,
                          height: 24,

                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StopDetailScreen(
                                        stop: stop,
                                      ),
                                ),
                              );
                            },

                            child: const Icon(
                              Icons.circle,
                              color:
                              Colors.black45,
                              size: 10,
                            ),
                          ),
                        ),
                      ),

                      // -----------------------------------------
                      // LIVE BUS MARKERS
                      // -----------------------------------------
                      ...transit.vehicles.map(
                            (vehicle) => Marker(
                          point: LatLng(
                            vehicle.lat,
                            vehicle.lng,
                          ),

                          width: 46,
                          height: 46,

                          child: Tooltip(
                            message:
                            'Bus ${transit.displayRouteLabel(vehicle.routeId)}',

                            child: const Icon(
                              Icons
                                  .directions_bus_filled_rounded,

                              color:
                              Colors.deepOrange,

                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // =================================================
              // LOADING INDICATOR
              // =================================================
              if (transit.vehiclesStatus ==
                  LoadStatus.loading &&
                  transit.vehicles.isEmpty)
                const Center(
                  child:
                  CircularProgressIndicator(),
                ),

              // =================================================
              // ERROR MESSAGE
              // =================================================
              if (transit.errorMessage != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,

                  child: Card(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer,

                    child: Padding(
                      padding:
                      const EdgeInsets.all(12),

                      child: Text(
                        transit.errorMessage!,

                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),

              // =================================================
              // NUMBER OF LIVE BUSES
              // =================================================
              Positioned(
                top: 12,
                left: 12,

                child: Chip(
                  avatar: const Icon(
                    Icons.directions_bus,
                    size: 18,
                  ),

                  label: Text(
                    '${transit.vehicles.length} buses live',
                  ),
                ),
              ),

              // =================================================
              // REFRESH LOADING ICON
              // =================================================
              if (transit.vehiclesStatus ==
                  LoadStatus.loading &&
                  transit.vehicles.isNotEmpty)
                const Positioned(
                  top: 15,
                  right: 15,

                  child: SizedBox(
                    width: 24,
                    height: 24,

                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
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
