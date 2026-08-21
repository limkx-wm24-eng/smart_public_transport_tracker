import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/route_model.dart';
import '../providers/favourites_provider.dart';
import '../widgets/route_list_tile.dart';
import 'route_detail_screen.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favourites = context.watch<FavouritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Favourite Lines')),
      body: favourites.favourites.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No favourite bus lines yet.\n'
                'Save one from the Bus Lines tab to see it here.',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: favourites.favourites.length,
        itemBuilder: (context, index) {
          final fav = favourites.favourites[index];
          final route = TransitRoute(
            routeId: fav.routeId,
            shortName: fav.shortName,
            longName: fav.longName,
          );
          return RouteListTile(
            route: route,
            isFavourite: true,
            onToggleFavourite: () =>
                context.read<FavouritesProvider>().toggleFavourite(route),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RouteDetailScreen(route: route),
              ),
            ),
          );
        },
      ),
    );
  }
}