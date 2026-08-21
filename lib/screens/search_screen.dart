import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stop.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import '../widgets/stop_list_tile.dart';
import 'stop_detail_screen.dart';

/// Member B's screen — search stops by name and save favourites.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Stop> _results = [];

  void _onQueryChanged(String query) {
    final transit = context.read<TransitProvider>();
    setState(() => _results = transit.searchStopsLocally(query));
  }

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();
    final favourites = context.watch<FavouritesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Stops TEST 123',
        ),
      ),
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
            const Expanded(
              child: Center(
                child: Text('Start typing to find a stop near you'),
              ),
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
                    onToggleFavourite: () =>
                        context.read<FavouritesProvider>().toggleFavourite(stop),
                    onTap: () {
                      debugPrint('CLICKED STOP: ${stop.name}');

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StopDetailScreen(
                            stop: stop,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
