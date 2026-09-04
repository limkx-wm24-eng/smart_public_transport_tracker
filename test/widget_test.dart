










import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_public_transport_tracker/models/stop.dart';
import 'package:smart_public_transport_tracker/widgets/stop_list_tile.dart';

void main() {
  testWidgets('StopListTile shows stop name and toggles favourite',
          (WidgetTester tester) async {
        const stop = Stop(
          stopId: '1000',
          name: 'Pasar Seni',
          lat: 3.1421,
          lng: 101.6952,
        );

        var isFavourite = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return StopListTile(
                    stop: stop,
                    isFavourite: isFavourite,
                    onToggleFavourite: () =>
                        setState(() => isFavourite = !isFavourite),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Pasar Seni'), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsOneWidget);

        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pump();

        expect(find.byIcon(Icons.star), findsOneWidget);
      });
}
