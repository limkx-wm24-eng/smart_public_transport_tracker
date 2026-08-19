import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/transit_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Network'),
            subtitle: Text(AppConstants.gtfsCategory),
            leading: Icon(Icons.alt_route),
          ),
          ListTile(
            title: const Text('Refresh stops data'),
            subtitle: Text('${transit.stops.length} stops cached'),
            leading: const Icon(Icons.download),
            trailing: transit.stopsStatus == LoadStatus.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        transit.loadStopsAndRoutes(forceRefresh: true),
                  ),
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Smart Public Transport Tracker',
            applicationVersion: '1.0.0',
            aboutBoxChildren: [
              Text(
                'Live transit data provided by Malaysia\'s official Open API '
                '(api.data.gov.my), sourced from Prasarana GTFS feeds.',
              ),
            ],
            child: Text('About'),
          ),
        ],
      ),
    );
  }
}
