import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/stop.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import '../services/location_service.dart';
import '../widgets/stop_list_tile.dart';
import 'stop_detail_screen.dart';

/// Search stops by name, save favourites, and — before the user types
/// anything — show the closest stops to their current GPS location so
/// they don't have to know a stop's name to get started.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final LocationService _locationService = LocationService();

  List<Stop> _results = [];
  Position? _myLocation;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locating = true);
    final pos = await _locationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _myLocation = pos;
        _locating = false;
      });
    }
  }

  void _onQueryChanged(String query) {
    final transit = context.read<TransitProvider>();
    setState(() => _results = transit.searchStopsLocally(query));
  }

  void _openStop(Stop stop) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StopDetailScreen(stop: stop)),
    );
  }

  /// The closest 8 stops to the user, nearest first.
  List<_NearbyStop> _nearestStops(List<Stop> allStops) {
    if (_myLocation == null) return [];

    final withDistance = allStops.map((stop) {
      final distance = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        stop.lat,
        stop.lng,
      );
      return _NearbyStop(stop: stop, distanceMetres: distance);
    }).toList();

    withDistance.sort((a, b) => a.distanceMetres.compareTo(b.distanceMetres));
    return withDistance.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();
    final favourites = context.watch<FavouritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Search Stops')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search for a bus stop...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    _onQueryChanged('');
                  },
                ),
              ),
            ),
          ),
          if (transit.stopsStatus == LoadStatus.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_controller.text.isEmpty)
            Expanded(
              child: _buildNearbyStops(context, transit, favourites),
            )
          else if (_results.isEmpty)
              const Expanded(
                child: Center(child: Text('No stops found')),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final stop = _results[index];
                    return StopListTile(
                      stop: stop,
                      isFavourite: favourites.isFavourite(stop.stopId),
                      onToggleFavourite: () => context
                          .read<FavouritesProvider>()
                          .toggleFavourite(stop),
                      onTap: () => _openStop(stop),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildNearbyStops(
      BuildContext context,
      TransitProvider transit,
      FavouritesProvider favourites,
      ) {
    if (_locating) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Finding stops near you...'),
            ],
          ),
        ),
      );
    }

    if (_myLocation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Enable location access to see stops near you, or search '
                    'by name above.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadLocation,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (transit.stops.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No stops loaded yet.\nTry again shortly or search by name '
                'above.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final nearby = _nearestStops(transit.stops);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Closest stops to you',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...nearby.map(
              (n) => StopListTile(
            stop: n.stop,
            isFavourite: favourites.isFavourite(n.stop.stopId),
            onToggleFavourite: () =>
                context.read<FavouritesProvider>().toggleFavourite(n.stop),
            onTap: () => _openStop(n.stop),
            trailingLabel: n.distanceLabel,
          ),
        ),
      ],
    );
  }
}

class _NearbyStop {
  final Stop stop;
  final double distanceMetres;

  _NearbyStop({required this.stop, required this.distanceMetres});

  String get distanceLabel {
    if (distanceMetres < 1000) return '${distanceMetres.round()} m';
    return '${(distanceMetres / 1000).toStringAsFixed(1)} km';
  }
}