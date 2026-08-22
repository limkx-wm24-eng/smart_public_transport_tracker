import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favourite_stop.dart';

/// Remote favourites storage backed by Supabase (a hosted Postgres
/// database) — the app's remote data saving method for user data.
///
/// Table (see README for the full SQL):
///   create table favourites (
///     id uuid primary key default gen_random_uuid(),
///     user_id uuid not null references auth.users(id) on delete cascade,
///     stop_id text not null,
///     name text not null,
///     lat double precision not null,
///     lng double precision not null,
///     saved_at timestamptz not null default now(),
///     unique (user_id, stop_id)
///   );
///
/// Rows are scoped by the authenticated user's id (auth.uid()), enforced
/// by real Row Level Security now that the app has a login system — this
/// replaces the earlier device_id workaround.
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