import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favourite_stop.dart';



















class SupabaseFavouritesService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<FavouriteStop>> fetchFavourites(String userId) async {
    final rows = await _client
        .from('favourites')
        .select()
        .eq('user_id', userId)
        .order('saved_at', ascending: false);

    return (rows as List)
        .map((row) => FavouriteStop(
      stopId: row['stop_id'] as String,
      name: row['name'] as String,
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
      savedAt: DateTime.parse(row['saved_at'] as String),
    ))
        .toList();
  }

  Future<void> addFavourite(String userId, FavouriteStop fav) async {
    await _client.from('favourites').upsert(
      {
        'user_id': userId,
        'stop_id': fav.stopId,
        'name': fav.name,
        'lat': fav.lat,
        'lng': fav.lng,
        'saved_at': fav.savedAt.toIso8601String(),
      },
      onConflict: 'user_id,stop_id',
    );
  }

  Future<void> removeFavourite(String userId, String stopId) async {
    await _client
        .from('favourites')
        .delete()
        .eq('user_id', userId)
        .eq('stop_id', stopId);
  }
}
