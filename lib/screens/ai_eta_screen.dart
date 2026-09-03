import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/public_transport_plan.dart';
import '../models/stop.dart';
import '../providers/transit_provider.dart';
import '../services/gemini_ai_service.dart';
import '../services/location_service.dart';
import '../services/route_planner_service.dart';
import 'route_detail_screen.dart';

class AiEtaScreen extends StatefulWidget {
  final Stop? initialStop;

  const AiEtaScreen({super.key, this.initialStop});

  @override
  State<AiEtaScreen> createState() => _AiEtaScreenState();
}

class _AiEtaScreenState extends State<AiEtaScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final LocationService _location = LocationService();
  final RoutePlannerService _planner = RoutePlannerService();
  final GeminiAiService _ai = GeminiAiService();

  LocationCandidate? _start;
  LocationCandidate? _destination;
  List<Stop> _startResults = [];
  List<Stop> _destinationResults = [];
  List<PublicTransportPlan> _plans = [];
  String? _aiAdvice;
  String? _error;
  String? _gpsNotice;
  bool _loadingLocation = false;
  bool _searching = false;
  RouteSortPreference _sortPreference = RouteSortPreference.shortestTravelTime;

  @override
  void initState() {
    super.initState();
    if (widget.initialStop != null) {
      _destination = _candidateFromStop(widget.initialStop!);
      _destinationController.text = widget.initialStop!.name;
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  LocationCandidate _candidateFromStop(Stop stop) {
    return LocationCandidate(
      name: stop.name,
      coordinate: LatLng(stop.lat, stop.lng),
      stop: stop,
    );
  }

  void _searchStart(String query) {
    final transit = context.read<TransitProvider>();
    setState(() {
      _start = null;
      _gpsNotice = null;
      _startResults = transit.searchStopsLocally(query).take(8).toList();
    });
  }

  void _searchDestination(String query) {
    final transit = context.read<TransitProvider>();
    setState(() {
      _destination = null;
      _destinationResults = transit.searchStopsLocally(query).take(8).toList();
    });
  }

  void _selectStart(Stop stop) {
    setState(() {
      _start = _candidateFromStop(stop);
      _startController.text = stop.name;
      _startResults = [];
      _gpsNotice = null;
    });
  }

  void _selectDestination(Stop stop) {
    setState(() {
      _destination = _candidateFromStop(stop);
      _destinationController.text = stop.name;
      _destinationResults = [];
    });
  }

  void _swapLocations() {
    setState(() {
      final oldStart = _start;
      final oldStartText = _startController.text;
      _start = _destination;
      _startController.text = _destinationController.text;
      _destination = oldStart;
      _destinationController.text = oldStartText;
      _startResults = [];
      _destinationResults = [];
      _plans = [];
      _aiAdvice = null;
      _error = null;
      _gpsNotice = null;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    final position = await _location.getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _loadingLocation = false;
        _error =
            'Location permission is required for Current Location. You can enter a location manually.';
      });
      return;
    }

    final transit = context.read<TransitProvider>();
    final nearest = _nearestStopForNotice(
      transit.stops,
      LatLng(position.latitude, position.longitude),
    );

    setState(() {
      _loadingLocation = false;
      _start = LocationCandidate(
        name: 'Current Location',
        coordinate: LatLng(position.latitude, position.longitude),
      );
      _startController.text = 'Current Location';
      _gpsNotice = nearest == null
          ? 'GPS found your coordinates, but no nearby bus stop was loaded.'
          : 'Current Location will use nearby stops automatically. Nearest stop: ${nearest.key.name} (${_distanceLabel(nearest.value)} away).';
      _startResults = [];
    });
  }

  Future<void> _searchRoutes() async {
    final transit = context.read<TransitProvider>();
    final start =
        _start ?? _candidateFromTypedStop(_startController.text, transit);
    final destination = _destination ??
        _candidateFromTypedStop(_destinationController.text, transit);
    if (start == null) {
      setState(
          () => _error = 'Choose a start location or use Current Location.');
      return;
    }
    if (destination == null) {
      setState(
          () => _error = 'Choose a destination from the stop search results.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
      _gpsNotice = null;
      _plans = [];
      _aiAdvice = null;
    });

    try {
      final plans = await _planner.findRoutes(
        start: start,
        destination: destination,
        transit: transit,
        preference: _sortPreference,
      );
      if (plans.isEmpty) {
        throw Exception(
          'No scheduled public transport route was found from this start area. Try another nearby start stop.',
        );
      }

      String? advice;
      try {
        advice = await _ai.getJourneyAdvice(
          question: 'Explain the best public transport route in simple steps.',
          transportContext: plans.first.toAiContext(),
        );
      } catch (_) {
        advice = null;
      }

      if (mounted) {
        setState(() {
          _plans = plans;
          _aiAdvice = advice;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  LocationCandidate? _candidateFromTypedStop(
    String value,
    TransitProvider transit,
  ) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty || query == 'current location') return null;

    for (final stop in transit.stops) {
      if (stop.name.trim().toLowerCase() == query) {
        return _candidateFromStop(stop);
      }
    }

    final matches = transit.searchStopsLocally(value);
    return matches.isEmpty ? null : _candidateFromStop(matches.first);
  }

  MapEntry<Stop, double>? _nearestStopForNotice(
    List<Stop> stops,
    LatLng coordinate,
  ) {
    if (stops.isEmpty) return null;
    final sorted = stops
        .map(
          (stop) => MapEntry(
            stop,
            const Distance().as(
              LengthUnit.Meter,
              coordinate,
              LatLng(stop.lat, stop.lng),
            ),
          ),
        )
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.first;
  }

  String _distanceLabel(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  void _openDetails(PublicTransportPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          plan: plan,
          aiAdvice: plan == _plans.first ? _aiAdvice : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner'),
        actions: [
          IconButton(
            tooltip: 'Refresh live buses',
            onPressed: () => transit.refreshVehicles(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _LocationField(
              controller: _startController,
              label: 'Start',
              hint: 'Current Location or search a stop',
              icon: Icons.trip_origin,
              onChanged: _searchStart,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _loadingLocation ? null : _useCurrentLocation,
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _loadingLocation ? 'Finding location...' : 'Current Location',
              ),
            ),
            if (_gpsNotice != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PlannerNotice(message: _gpsNotice!),
              ),
            _StopResults(results: _startResults, onSelected: _selectStart),
            const SizedBox(height: 12),
            _LocationField(
              controller: _destinationController,
              label: 'Destination',
              hint: 'Search destination, e.g. KLCC',
              icon: Icons.location_on_outlined,
              onChanged: _searchDestination,
            ),
            _StopResults(
              results: _destinationResults,
              onSelected: _selectDestination,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RouteSortPreference>(
              initialValue: _sortPreference,
              decoration: const InputDecoration(
                labelText: 'Sort routes by',
                prefixIcon: Icon(Icons.tune),
              ),
              items: const [
                DropdownMenuItem(
                  value: RouteSortPreference.shortestTravelTime,
                  child: Text('Shortest travel time'),
                ),
                DropdownMenuItem(
                  value: RouteSortPreference.fewestTransfers,
                  child: Text('Least cost / fewest line changes'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sortPreference = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _swapLocations,
                    icon: const Icon(Icons.swap_vert),
                    label: const Text('Swap'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.schedule),
                    label: const Text('Depart Now'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _searching ? null : _searchRoutes,
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_searching ? 'Searching routes...' : 'Search Route'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_plans.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Suggested routes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._plans.map(
                (plan) => _RouteSuggestionCard(
                  plan: plan,
                  onTap: () => _openDetails(plan),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _StopResults extends StatelessWidget {
  const _StopResults({
    required this.results,
    required this.onSelected,
  });

  final List<Stop> results;
  final ValueChanged<Stop> onSelected;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: results
            .map(
              (stop) => ListTile(
                dense: true,
                leading: const Icon(Icons.directions_bus_outlined),
                title: Text(stop.name),
                subtitle: Text('Stop ID: ${stop.stopId}'),
                onTap: () => onSelected(stop),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PlannerNotice extends StatelessWidget {
  const _PlannerNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _RouteSuggestionCard extends StatelessWidget {
  const _RouteSuggestionCard({
    required this.plan,
    required this.onTap,
  });

  final PublicTransportPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${plan.totalDurationMinutes} min',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    plan.estimatedFare == null
                        ? 'Fare unavailable'
                        : 'RM${plan.estimatedFare!.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Arrival ${_formatTime(plan.arrivalTime)}'),
              const SizedBox(height: 10),
              Text(
                plan.routeSummary,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.directions_walk, size: 16),
                    label: Text('${plan.walkingMinutes} min walk'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.swap_calls, size: 16),
                    label: Text('${plan.transfers} transfers'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(
                      plan.vehicle == null
                          ? 'Scheduled estimate'
                          : 'Leaves: ${plan.legs[1].realtimeEta}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
