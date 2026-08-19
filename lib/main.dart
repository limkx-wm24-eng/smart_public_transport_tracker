import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/favourites_provider.dart';
import 'providers/transit_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const SmartTransportApp());
}

class SmartTransportApp extends StatelessWidget {
  const SmartTransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransitProvider()),
        ChangeNotifierProvider(create: (_) => FavouritesProvider()),
      ],
      child: MaterialApp(
        title: 'Smart Public Transport Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
