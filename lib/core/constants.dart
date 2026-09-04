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
  // Keep Rapid KL city-bus routes and stops available for route 250, etc.
  static const String gtfsCategory = 'rapid-bus-kl';

  // The city-bus realtime feed is currently empty. Use the available MRT
  // feeder vehicle feed for live map markers without replacing the catalogue.
  static const String gtfsRealtimeCategory = 'rapid-bus-mrtfeeder';

  // Realtime buses around Klang Valley can be split across Prasarana feeds.
  // Keep GTFS static on rapid-bus-kl for the existing stops/routes cache, but
  // combine live vehicle positions from both bus feeds on the Live Tracker.
  static const List<String> gtfsRealtimeCategories = [
    'rapid-bus-kl',
    'rapid-bus-mrtfeeder',
  ];

  static const String gtfsStaticBaseUrl =
      'https://api.data.gov.my/gtfs-static/prasarana';

  static const String gtfsRealtimeBaseUrl =
      'https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana';

  static String get gtfsStaticUrl =>
      '$gtfsStaticBaseUrl?category=$gtfsCategory';

  static String get gtfsRealtimeUrl =>
      '$gtfsRealtimeBaseUrl?category=$gtfsRealtimeCategory';

  // How often to poll the realtime feed for new vehicle positions.
  // data.gov.my exposes GTFS-Realtime as an HTTP feed, not a push listener.
  static const Duration realtimePollInterval = Duration(seconds: 45);

  // How long cached static data (stops/routes) stays valid before refresh.
  static const Duration staticDataMaxAge = Duration(hours: 24);

  // Default map camera (Kuala Lumpur city centre) — used before GPS locks on.
  static const double defaultLat = 3.1390;
  static const double defaultLng = 101.6869;
  static const double defaultZoom = 13.0;

  // Local SQLite database (offline cache: stops, routes, favourites mirror)
  static const String dbName = 'transit_tracker.db';
  static const int dbVersion = 2;

  // Supabase project credentials (remote database — favourites sync).
  static const String supabaseUrl = 'https://gxdumicthspqfvvmzjtz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4ZHVtaWN0aHNwcWZ2dm16anR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0MDQ3MDksImV4cCI6MjEwMjk4MDcwOX0.bGMN681VijMZlwyWLF5s8AU58y3A2Nq_wFaVu-O_YyU';

  // Where Supabase confirmation / password-reset email links send the user
  // back to. This custom scheme is registered in AndroidManifest.xml (Android)
  // and Info.plist (iOS) so it opens THIS app instead of a browser.
  //
  // IMPORTANT: this exact URL (or "io.supabase.smarttransport://login-callback/**")
  // must also be added under Supabase dashboard -> Authentication ->
  // URL Configuration -> Redirect URLs, or Supabase will reject it and
  // silently fall back to the default Site URL (localhost).
  static const String authRedirectUrl =
      'io.supabase.smarttransport://login-callback/';
}
