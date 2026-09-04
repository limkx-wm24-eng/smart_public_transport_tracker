










String estimateEtaLabel(double distanceMetres) {
  const assumedSpeedMetresPerMinute = 300;
  final minutes = (distanceMetres / assumedSpeedMetresPerMinute).ceil();
  if (minutes <= 1) return 'Arriving now';
  return '~$minutes min';
}







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












SmartEtaResult estimateSmartEta({
  required double distanceMetres,
  int? stopsRemaining,
  int dwellSecondsPerStop = 20,
}) {
  const assumedSpeedMetresPerMinute = 300;

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
