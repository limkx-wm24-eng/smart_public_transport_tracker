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

/// Result of a "smart" (schedule-aware) arrival estimate — used by the
/// AI-Estimated Arrival Time feature.
///
/// [scheduleAware] is true when [stopsRemaining] was worked out from the
/// bus's actual GTFS trip (how many scheduled stops away it currently is),
/// rather than from straight-line distance alone.
class SmartEtaResult {
  final int minutes;
  final String label;
  final int? stopsRemaining;
  final bool scheduleAware;
  final double distanceMetres;
  final String confidenceLabel;
  final String basis;

  const SmartEtaResult({
    required this.minutes,
    required this.label,
    required this.stopsRemaining,
    required this.scheduleAware,
    required this.distanceMetres,
    required this.confidenceLabel,
    required this.basis,
  });
}

/// Combines distance ÷ assumed-speed with the number of scheduled stops a
/// bus still has to serve before reaching the target stop.
///
/// Distance alone can be misleading: a bus 200 m away in a straight line
/// might still have to serve four stops before yours, each with real
/// dwell/turning time. Adding a fixed [dwellSecondsPerStop] per remaining
/// stop is still an approximation (not official GTFS trip-updates data —
/// data.gov.my doesn't publish that feed) but is noticeably more realistic
/// than distance alone. When [stopsRemaining] is null (no trip ID, the
/// stop isn't on this trip, or the bus already appears to have passed it),
/// this falls back to the plain distance estimate.
SmartEtaResult estimateSmartEta({
  required double distanceMetres,
  int? stopsRemaining,
  int dwellSecondsPerStop = 20,
}) {
  const assumedSpeedMetresPerMinute = 300; // ~18 km/h typical urban bus

  final travelMinutes = distanceMetres / assumedSpeedMetresPerMinute;
  final dwellMinutes = (stopsRemaining ?? 0) * dwellSecondsPerStop / 60;

  var minutes = (travelMinutes + dwellMinutes).ceil();
  if (minutes < 1) minutes = 1;

  final label = minutes <= 1 ? 'Arriving now' : '~$minutes min';

  return SmartEtaResult(
    minutes: minutes,
    label: label,
    stopsRemaining: stopsRemaining,
    scheduleAware: stopsRemaining != null,
    distanceMetres: distanceMetres,
    confidenceLabel:
        stopsRemaining == null ? 'Nearby estimate' : 'Trip matched',
    basis: stopsRemaining == null
        ? 'Distance-only estimate'
        : 'Trip sequence + distance estimate',
  );
}
