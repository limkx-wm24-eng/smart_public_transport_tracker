import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stop.dart';
import '../providers/favourites_provider.dart';
import '../widgets/stop_list_tile.dart';
import 'stop_detail_screen.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favourites = context.watch<FavouritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Favourite Stops')),
      body: favourites.favourites.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No favourite stops yet.\n'
                'Save one from the Search tab or a stop\'s detail screen '
                'to see it here.',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: favourites.favourites.length,
        itemBuilder: (context, index) {
          final fav = favourites.favourites[index];
          final stop = Stop(
            stopId: fav.stopId,
            name: fav.name,
            lat: fav.lat,
            lng: fav.lng,
          );
          return StopListTile(
            stop: stop,
            isFavourite: true,
            onToggleFavourite: () =>
                context.read<FavouritesProvider>().toggleFavourite(stop),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StopDetailScreen(stop: stop),
              ),
            ),
          );
        },
      ),
    );
  }
}