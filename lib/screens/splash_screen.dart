import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/favourites_provider.dart';
import '../providers/transit_provider.dart';
import '../widgets/root_nav.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final transit = context.read<TransitProvider>();
    final auth = context.read<AuthProvider>();
    final favourites = context.read<FavouritesProvider>();

    // Transit data (stops/routes/live buses) doesn't require a login, so
    // kick it off immediately rather than waiting on anything else first.
    final transitFuture = transit.initialise();

    if (!auth.isLoggedIn) {
      // Nothing else to load for a logged-out user — just wait for
      // transit data and head to the login screen.
      await transitFuture;

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Logged in: profile and favourites are independent of the transit
    // data (and of each other), so load everything in parallel instead
    // of one thing at a time — this is what was making the splash
    // screen take noticeably longer for logged-in users.
    await Future.wait([
      transitFuture,
      auth.loadProfile(),
      favourites.load(),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootNav()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_bus_filled_rounded, size: 72),
            SizedBox(height: 16),
            Text(
              'Smart Public Transport Tracker',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}