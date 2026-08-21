import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/recommended_route.dart';
import '../models/route_model.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import '../services/location_service.dart';
import '../widgets/route_list_tile.dart';
import 'route_detail_screen.dart';

/// Member B's screen — search bus lines by number/name, save favourites,
/// and see lines recommended based on the user's current location.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final LocationService _locationService = LocationService();

  List<TransitRoute> _results = [];
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
    setState(() => _results = transit.searchRoutesLocally(query));
  }

  void _openRoute(TransitRoute route) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();
    final favourites = context.watch<FavouritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Bus Lines')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search bus line, e.g. 250 or T250',
                prefixIcon: const Icon(Icons.directions_bus_outlined),
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
              child: _buildRecommendations(context, transit, favourites),
            )
          else if (_results.isEmpty)
              const Expanded(
                child: Center(child: Text('No bus lines found')),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final route = _results[index];
                    return RouteListTile(
                      route: route,
                      isFavourite: favourites.isFavourite(route.routeId),
                      onToggleFavourite: () =>
                          context.read<FavouritesProvider>().toggleFavourite(route),
                      onTap: () => _openRoute(route),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(
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
              Text('Finding buses near you...'),
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
                'Enable location access to see bus lines running near you.',
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

    final recommended = transit.recommendedRoutes(
      userLat: _myLocation!.latitude,
      userLng: _myLocation!.longitude,
    );

    if (recommended.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No buses currently tracked near you.\n'
                'Try searching for a specific line instead.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Recommended near you',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...recommended.map((rec) => _RecommendedRouteTile(
          recommended: rec,
          isFavourite: favourites.isFavourite(rec.routeId),
          onToggleFavourite: () {
            final route = transit.routes.firstWhere(
                  (r) => r.routeId == rec.routeId,
              orElse: () => TransitRoute(
                routeId: rec.routeId,
                shortName: rec.label,
                longName: '',
              ),
            );
            context.read<FavouritesProvider>().toggleFavourite(route);
          },
          onTap: () {
            final route = transit.routes.firstWhere(
                  (r) => r.routeId == rec.routeId,
              orElse: () => TransitRoute(
                routeId: rec.routeId,
                shortName: rec.label,
                longName: '',
              ),
            );
            _openRoute(route);
          },
        )),
      ],
    );
  }
}

class _RecommendedRouteTile extends StatelessWidget {
  final RecommendedRoute recommended;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback onTap;

  const _RecommendedRouteTile({
    required this.recommended,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            recommended.label.length > 4
                ? recommended.label.substring(0, 4)
                : recommended.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text('Bus ${recommended.label}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${recommended.distanceLabel} · ${recommended.vehicleCountNearby} '
              'nearby',
        ),
        trailing: IconButton(
          icon: Icon(
            isFavourite ? Icons.star : Icons.star_border,
            color: isFavourite ? Colors.amber : null,
          ),
          onPressed: onToggleFavourite,
        ),
      ),
    );
  }
}