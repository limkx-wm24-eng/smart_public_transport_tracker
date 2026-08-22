// Basic smoke test.
//
// Note: SmartTransportApp (main.dart) calls Supabase.initialize() before
// runApp(), and most screens (SplashScreen, HomeMapScreen, etc.) read
// TransitProvider/AuthProvider/FavouritesProvider from context — which in
// turn depend on that Supabase bootstrap having already run. None of that
// is available in a plain widget-test environment, so this test instead
// exercises StopListTile, a real, self-contained widget from the app that
// needs no providers or backend calls, to check it renders correctly and
// that its favourite toggle works.

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