import 'package:flutter/material.dart';

import '../screens/favourites_screen.dart';
import '../screens/ai_eta_screen.dart';
import '../screens/home_map_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/ai_support_page.dart';

/// Shell widget holding the bottom navigation bar.
/// AI Support stays available as a draggable floating bubble so the main
/// navigation is less crowded on mobile.
class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;
  Offset? _supportBubbleOffset;

  static const _screens = [
    HomeMapScreen(),
    SearchScreen(),
    FavouritesScreen(),
    AiEtaScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bubbleOffset = _supportBubbleOffset ??
              Offset(
                constraints.maxWidth - 84,
                constraints.maxHeight - 108,
              );

          return Stack(
            children: [
              IndexedStack(index: _index, children: _screens),
              if (_index != 3)
                Positioned(
                  left: bubbleOffset.dx,
                  top: bubbleOffset.dy,
                  child: _SupportBubble(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AiSupportPage(),
                        ),
                      );
                    },
                    onDrag: (delta) {
                      setState(() {
                        final next = bubbleOffset + delta;
                        _supportBubbleOffset = Offset(
                          next.dx.clamp(12, constraints.maxWidth - 68),
                          next.dy.clamp(96, constraints.maxHeight - 84),
                        );
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Live Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Bus Lines',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Favourites',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _SupportBubble extends StatelessWidget {
  const _SupportBubble({
    required this.onTap,
    required this.onDrag,
  });

  final VoidCallback onTap;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: (details) => onDrag(details.delta),
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        elevation: 6,
        shape: const CircleBorder(),
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.support_agent,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
