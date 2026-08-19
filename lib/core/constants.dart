/// App-wide constants: API endpoints, default map values, etc.
///
/// Data source: Malaysia's official Open API (api.data.gov.my)
/// Docs: https://developer.data.gov.my/realtime-api/gtfs-realtime
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // GTFS category. Change this to switch network:
  //   rapid-bus-kl, rapid-rail-kl, rapid-bus-penang, rapid-bus-kuantan,
  //   rapid-bus-mrtfeeder
  // ---------------------------------------------------------------------
  static const String gtfsCategory = 'rapid-bus-kl';

  static const String gtfsStaticBaseUrl =
      'https://api.data.gov.my/gtfs-static/prasarana';

  static const String gtfsRealtimeBaseUrl =
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana';

  static String get gtfsStaticUrl => '$gtfsStaticBaseUrl?category=$gtfsCategory';

  static String get gtfsRealtimeUrl =>
      '$gtfsRealtimeBaseUrl?category=$gtfsCategory';

  // How often to poll the realtime feed for new vehicle positions.
  static const Duration realtimePollInterval = Duration(seconds: 20);

  // How long cached static data (stops/routes) stays valid before refresh.
  static const Duration staticDataMaxAge = Duration(hours: 24);

  // Default map camera (Kuala Lumpur city centre) — used before GPS locks on.
  static const double defaultLat = 3.1390;
  static const double defaultLng = 101.6869;
  static const double defaultZoom = 13.0;

  static const String dbName = 'transit_tracker.db';
  static const int dbVersion = 1;
}
