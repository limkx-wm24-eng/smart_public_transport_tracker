import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/stop.dart';
import '../models/route_model.dart';
import '../models/favourite_stop.dart';

/// Single source of truth for local (on-device) storage.
///
/// Two tables:
///  - `stops`      : cached copy of GTFS-Static stops (refreshed periodically)
///  - `favourites` : user's saved stops (never expires, user-controlled)
///
/// This satisfies the assignment's "local + remote data saving methods"
/// requirement — remote realtime data feeds the map, local SQLite backs
/// search history and favourites.
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
          CREATE TABLE favourites (
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

  Future<List<Stop>> searchStops(String query) async {
    final db = await database;
    final rows = await db.query(
      'stops',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 30,
    );
    return rows.map(Stop.fromMap).toList();
  }

  Future<bool> shouldRefreshStops() async {
    final lastSyncedStr = await _getMeta('stops_last_synced');
    if (lastSyncedStr == null) return true;
    final lastSynced = DateTime.tryParse(lastSyncedStr);
    if (lastSynced == null) return true;
    return DateTime.now().difference(lastSynced) > AppConstants.staticDataMaxAge;
  }

  // ------------------------------------------------------------------
  // Routes cache (populated from GTFS-Static, used to label ETAs with
  // human-readable bus numbers instead of raw route_id)
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
  // Favourites (Member B's module)
  // ------------------------------------------------------------------

  Future<void> addFavourite(FavouriteStop fav) async {
    final db = await database;
    await db.insert('favourites', fav.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavourite(String stopId) async {
    final db = await database;
    await db.delete('favourites', where: 'stop_id = ?', whereArgs: [stopId]);
  }

  Future<List<FavouriteStop>> getFavourites() async {
    final db = await database;
    final rows = await db.query('favourites', orderBy: 'saved_at DESC');
    return rows.map(FavouriteStop.fromMap).toList();
  }

  Future<bool> isFavourite(String stopId) async {
    final db = await database;
    final rows = await db.query('favourites',
        where: 'stop_id = ?', whereArgs: [stopId], limit: 1);
    return rows.isNotEmpty;
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
