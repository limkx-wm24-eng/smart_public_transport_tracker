/// Converts a distance (metres) into a rough arrival-time estimate.
///
/// This is a simple distance ÷ assumed-speed calculation — NOT an official
/// prediction. data.gov.my currently only publishes live vehicle
/// positions, not a trip-updates (predicted arrival) feed, so there's no
/// "official" ETA to pull from the API. This estimates arrival from how
/// far away the bus currently is, assuming typical urban bus speed.
///
/// Worth naming as a known limitation in your report/demo: real-world
/// traffic, stops the bus must serve first, and road routing aren't
/// accounted for.
String estimateEtaLabel(double distanceMetres) {
  const assumedSpeedMetresPerMinute = 300; // ~18 km/h typical urban bus
  final minutes = (distanceMetres / assumedSpeedMetresPerMinute).ceil();
  if (minutes <= 1) return 'Arriving now';
  return '~$minutes min';
}