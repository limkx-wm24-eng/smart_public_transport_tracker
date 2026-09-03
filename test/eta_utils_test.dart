import 'package:flutter_test/flutter_test.dart';
import 'package:smart_public_transport_tracker/core/eta_utils.dart';

void main() {
  test('estimateSmartEta falls back to distance-only when stop count is absent',
      () {
    final eta = estimateSmartEta(distanceMetres: 600);

    expect(eta.minutes, 2);
    expect(eta.label, '~2 min');
    expect(eta.scheduleAware, isFalse);
    expect(eta.stopsRemaining, isNull);
    expect(eta.confidenceLabel, 'Nearby estimate');
    expect(eta.basis, 'Distance-only estimate');
  });

  test('estimateSmartEta includes stop dwell time when trip sequence is known',
      () {
    final eta = estimateSmartEta(distanceMetres: 600, stopsRemaining: 3);

    expect(eta.minutes, 3);
    expect(eta.label, '~3 min');
    expect(eta.scheduleAware, isTrue);
    expect(eta.stopsRemaining, 3);
    expect(eta.confidenceLabel, 'Trip matched');
    expect(eta.basis, 'Trip sequence + distance estimate');
  });
}
