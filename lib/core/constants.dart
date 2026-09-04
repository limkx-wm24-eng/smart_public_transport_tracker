



class AppConstants {
  AppConstants._();







  static const String gtfsCategory = 'rapid-bus-kl';



  static const String gtfsRealtimeCategory = 'rapid-bus-mrtfeeder';




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



  static const Duration realtimePollInterval = Duration(seconds: 45);


  static const Duration staticDataMaxAge = Duration(hours: 24);


  static const double defaultLat = 3.1390;
  static const double defaultLng = 101.6869;
  static const double defaultZoom = 13.0;


  static const String dbName = 'transit_tracker.db';
  static const int dbVersion = 2;


  static const String supabaseUrl = 'https://gxdumicthspqfvvmzjtz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4ZHVtaWN0aHNwcWZ2dm16anR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0MDQ3MDksImV4cCI6MjEwMjk4MDcwOX0.bGMN681VijMZlwyWLF5s8AU58y3A2Nq_wFaVu-O_YyU';









  static const String authRedirectUrl =
      'io.supabase.smarttransport://login-callback/';
}
