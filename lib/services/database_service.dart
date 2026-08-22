import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/favourite_stop.dart';
import '../models/route_model.dart';
import '../models/stop.dart';

/// Local (on-device) storage via SQLite.
///
/// This app uses SQLite (here) AND Supabase (see
/// SupabaseFavouritesService) together, each for a different job:
///
///  - SQLite  : fast offline cache. Stops/routes downloaded from GTFS-
///              Static live here so the app works without a constant
///              connection, and favourites are mirrored here too so they
///              show up instantly and still work offline.
///  - Supabase: the source of truth for favourites. When online, this app
///              reads/writes favourites to a real Postgres database in the
///              cloud, so they'd survive a reinstall or (with a proper
///              login system added later) sync across devices.
///
/// See FavouritesProvider for how the two are reconciled.
///
/// Tables:
///  - `stops`            : cached GTFS-Static stops
///  - `routes`           : cached GTFS-Static routes
///  - `favourites_cache` : local mirror of the user's favourite stops
///  - `meta`             : small key-value bucket (e.g. last sync time)
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE stops (
            stop_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE routes (
            route_id TEXT PRIMARY KEY,
            short_name TEXT NOT NULL,
            long_name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE favourites_cache (
            stop_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            saved_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ------------------------------------------------------------------
  // Stops cache (populated from GTFS-Static)
  // ------------------------------------------------------------------

  Future<void> replaceStops(List<Stop> stops) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('stops');
    for (final s in stops) {
      batch.insert('stops', s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await _setMeta('stops_last_synced', DateTime.now().toIso8601String());
  }

  Future<List<Stop>> getAllStops() async {
    final db = await database;
    final rows = await db.query('stops');
    return rows.map(Stop.fromMap).toList();
  }

  Future<bool> shouldRefreshStops() async {
    final lastSyncedStr = await _getMeta('stops_last_synced');
    if (lastSyncedStr == null) return true;
    final lastSynced = DateTime.tryParse(lastSyncedStr);
    if (lastSynced == null) return true;
    return DateTime.now().difference(lastSynced) >
        AppConstants.staticDataMaxAge;
  }

  // ------------------------------------------------------------------
  // Routes cache (populated from GTFS-Static)
  // ------------------------------------------------------------------

  Future<void> replaceRoutes(List<TransitRoute> routes) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('routes');
    for (final r in routes) {
      batch.insert('routes', r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<TransitRoute>> getAllRoutes() async {
    final db = await database;
    final rows = await db.query('routes');
    return rows.map(TransitRoute.fromMap).toList();
  }

  // ------------------------------------------------------------------
  // Local favourites cache — mirrors Supabase for instant + offline access.
  // Supabase remains the source of truth; see FavouritesProvider.
  // ------------------------------------------------------------------

  Future<void> cacheFavourites(List<FavouriteStop> favs) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('favourites_cache');
    for (final f in favs) {
      batch.insert('favourites_cache', f.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheAddFavourite(FavouriteStop fav) async {
    final db = await database;
    await db.insert('favourites_cache', fav.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cacheRemoveFavourite(String stopId) async {
    final db = await database;
    await db.delete('favourites_cache',
        where: 'stop_id = ?', whereArgs: [stopId]);
  }

  Future<List<FavouriteStop>> getCachedFavourites() async {
    final db = await database;
    final rows = await db.query('favourites_cache', orderBy: 'saved_at DESC');
    return rows.map(FavouriteStop.fromMap).toList();
  }

  // ------------------------------------------------------------------
  // Small key-value helper table
  // ------------------------------------------------------------------

  Future<void> _setMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> _getMeta(String key) async {
    final db = await database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }
}