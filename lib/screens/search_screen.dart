import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/stop.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import '../services/location_service.dart';
import '../services/groq_ai_service.dart';
import '../services/journey_planner_service.dart';
import '../widgets/stop_list_tile.dart';
import 'stop_detail_screen.dart';




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
  bool _planningJourney = false;
  JourneyPlan? _journey;
  String? _journeyAdvice;
  String? _journeyError;
  final _planner = JourneyPlannerService();
  final _ai = GroqAiService();

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

  Future<void> _findJourney() async {
    final destination = _controller.text.trim();
    if (destination.isEmpty) return;
    setState(() { _planningJourney = true; _journeyError = null; _journey = null; _journeyAdvice = null; });
    try {
      final position = _myLocation ?? await _locationService.getCurrentPosition();
      if (position == null) throw Exception('Location permission is required to plan a journey.');
      final plan = await _planner.plan(destination: destination, latitude: position.latitude, longitude: position.longitude, transit: context.read<TransitProvider>());
      if (plan == null) throw Exception('No nearby stops are available yet.');
      String? advice;
      if (plan.route != null) advice = await _ai.getJourneyAdvice(question: 'Give concise journey instructions to $destination.', transportContext: plan.toContext(position.latitude, position.longitude));
      if (mounted) setState(() { _journey = plan; _journeyAdvice = advice; });
    } catch (error) {
      if (mounted) setState(() => _journeyError = error.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _planningJourney = false); }
  }


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
          if (_controller.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: FilledButton.icon(
                onPressed: _planningJourney ? null : _findJourney,
                icon: _planningJourney ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                label: const Text('Plan journey with AI'),
              ),
            ),
          if (_journeyError != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_journeyError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_journey != null) _buildJourneyCard(_journey!),
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

  Widget _buildJourneyCard(JourneyPlan plan) => Card(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Journey to ${plan.destination}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('Nearest stop: ${plan.nearestStop.name}'),
      Text('Walk: ${plan.walkMetres.round()} m • about ${plan.walkingMinutes} min'),
      if (plan.route != null) ...[Text('Recommended: Bus ${plan.route!.displayLabel}'), Text('Bus arrival: ${plan.busEta ?? 'Live bus information is currently unavailable.'}'), if (plan.journeyMinutes != null) Text('Estimated total journey: about ${plan.journeyMinutes} min')],
      if (plan.route == null) const Text('No matching direct route was found. Try a nearby destination stop name.'),
      if (!plan.realtimeAvailable) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Live bus information is currently unavailable.')),
      if (_journeyAdvice != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_journeyAdvice!)),
      TextButton.icon(onPressed: () => _openStop(plan.nearestStop), icon: const Icon(Icons.map_outlined), label: const Text('Show Route on Map')),
    ])),
  );

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
