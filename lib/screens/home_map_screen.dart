import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/transit_provider.dart';
import '../services/location_service.dart';
import 'stop_detail_screen.dart';

/// Member A's screen — live bus locations on a map.
/// Uses OpenStreetMap tiles via flutter_map (no billing/API key needed,
/// unlike Google Maps).
class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  Future<void> _locateMe() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_myLocation!, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracker'),
        actions: [
          IconButton(
            tooltip: 'Centre on my location',
            onPressed: _locateMe,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Consumer<TransitProvider>(
        builder: (context, transit, _) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(
                    AppConstants.defaultLat,
                    AppConstants.defaultLng,
                  ),
                  initialZoom: AppConstants.defaultZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.smart_public_transport_tracker',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_myLocation != null)
                        Marker(
                          point: _myLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.person_pin_circle,
                              color: Colors.blue, size: 36),
                        ),
                      // Tappable stop markers — opens the live ETA list.
                      // Capped to avoid rendering thousands of markers at
                      // once; zoom in for denser areas, or filter by
                      // distance from _myLocation for a smarter subset.
                      ...transit.stops.take(300).map(
                            (stop) => Marker(
                              point: LatLng(stop.lat, stop.lng),
                              width: 24,
                              height: 24,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StopDetailScreen(stop: stop),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.circle,
                                  color: Colors.black45,
                                  size: 10,
                                ),
                              ),
                            ),
                          ),
                      ...transit.vehicles.map(
                        (v) => Marker(
                          point: LatLng(v.lat, v.lng),
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.directions_bus_filled_rounded,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (transit.vehiclesStatus == LoadStatus.loading &&
                  transit.vehicles.isEmpty)
                const Center(child: CircularProgressIndicator()),
              if (transit.errorMessage != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
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
              Positioned(
                top: 12,
                left: 12,
                child: Chip(
                  avatar: const Icon(Icons.directions_bus, size: 18),
                  label: Text('${transit.vehicles.length} buses live'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
