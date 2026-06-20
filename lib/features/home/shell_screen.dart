import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'dashboard_screen.dart';
import 'discover_screen.dart';
import 'explore_screen.dart';
import 'my_wiki_screen.dart';
import 'profile_screen.dart';

/// Root tab shell: My Jams · Participate · Explore · My Wiki · Profile.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(authControllerProvider).isGuest;
    // Guests have no dashboard data; start them on Participate.
    final pages = [
      if (!isGuest) const DashboardScreen(),
      const ParticipateScreen(),
      const ExploreScreen(),
      if (!isGuest) const MyWikiScreen(),
      const ProfileScreen(),
    ];
    final destinations = [
      if (!isGuest)
        const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'My Jams'),
      const NavigationDestination(
          icon: Icon(Icons.how_to_reg_outlined),
          selectedIcon: Icon(Icons.how_to_reg),
          label: 'Participate'),
      const NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Explore'),
      if (!isGuest)
        const NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'My Wiki'),
      const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile'),
    ];
    final index = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
