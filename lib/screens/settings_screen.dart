import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await context.read<AuthProvider>().signOut();
    context.read<FavouritesProvider>().clearOnSignOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final transit = context.watch<TransitProvider>();
    final auth = context.watch<AuthProvider>();
    final name = auth.profile?['name'] as String? ?? 'Commuter';
    final email = auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
            ),
            title: Text(name),
            subtitle: Text(email),
          ),
          const Divider(),
          const ListTile(
            title: Text('Network'),
            subtitle: Text(
              '${AppConstants.gtfsCategory} routes · '
              '${AppConstants.gtfsRealtimeCategory} live vehicles',
            ),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
