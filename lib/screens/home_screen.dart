import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/audio_player_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/mini_player.dart';
import 'discover_screen.dart';
import 'marketplace_screen.dart';
import 'playlists_screen.dart';
import 'profile_screen.dart';
import 'sound_kits_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final catalog = context.read<CatalogProvider>();
      context.read<AudioPlayerProvider>().onTrackPlayed = (trackId) {
        catalog.incrementTrackPlays(trackId);
      };
    });
  }

  final List<Widget> _screens = const [
    DiscoverScreen(),
    PlaylistsScreen(),
    SoundKitsScreen(),
    MarketplaceScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopOrWeb = width >= 768;

    if (isDesktopOrWeb) {
      // Responsive layout with NavigationRail for Web / iPad / Desktop
      return Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    backgroundColor: AppTheme.surfaceColor,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (val) => setState(() => _currentIndex = val),
                    labelType: NavigationRailLabelType.all,
                    selectedIconTheme: const IconThemeData(color: AppTheme.primaryPurple),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    unselectedIconTheme: const IconThemeData(color: AppTheme.textSecondary),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryPurple, AppTheme.secondaryCyan],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.music_note_outlined),
                        selectedIcon: Icon(Icons.music_note_rounded),
                        label: Text('Discover'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.queue_music_outlined),
                        selectedIcon: Icon(Icons.queue_music_rounded),
                        label: Text('Playlists'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.album_outlined),
                        selectedIcon: Icon(Icons.album_rounded),
                        label: Text('Sound Kits'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.checkroom_outlined),
                        selectedIcon: Icon(Icons.checkroom_rounded),
                        label: Text('Merch'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: Text('Profile'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                ],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      );
    }

    // Mobile layout for iPhone & Android
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (val) => setState(() => _currentIndex = val),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.music_note_outlined),
                activeIcon: Icon(Icons.music_note_rounded),
                label: 'Discover',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.queue_music_outlined),
                activeIcon: Icon(Icons.queue_music_rounded),
                label: 'Playlists',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.album_outlined),
                activeIcon: Icon(Icons.album_rounded),
                label: 'Sound Kits',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.checkroom_outlined),
                activeIcon: Icon(Icons.checkroom_rounded),
                label: 'Merch',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
