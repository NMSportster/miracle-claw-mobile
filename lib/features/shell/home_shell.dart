import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/chat_screen.dart';
import '../settings/connected_devices_screen.dart';
import '../../core/pairing/discovery_state.dart';

/// Top-level shell after sign-in. v1 has two destinations:
///   - Chat (default — the primary use case)
///   - Connected Devices (Phase 3 — pair with a desktop, view status)
///
/// Uses `Drawer` rather than `NavigationRail` so it works on phones in
/// portrait without taking permanent screen space. Material 3 design
/// guidance: NavigationDrawer is the mobile-friendly pattern when there
/// are 2–5 top-level destinations.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    _NavDestination(
      label: 'Connected Devices',
      icon: Icons.devices_other,
      selectedIcon: Icons.devices,
    ),
  ];

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return const ChatScreen();
      case 1:
        return const ConnectedDevicesScreen();
      default:
        return const ChatScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairingState = ref.watch(connectionStateProvider);
    // Badge the "Connected Devices" entry when we have an active pairing
    // (so the user notices the green dot after first pairing).
    final showPairingBadge = pairingState is Paired;

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_selectedIndex].label),
      ),
      drawer: NavigationDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          Navigator.of(context).pop(); // close the drawer
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 10),
            child: Text(
              'Miracle Claw',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (var i = 0; i < _destinations.length; i++)
            NavigationDrawerDestination(
              icon: i == 1 && showPairingBadge
                  ? Badge(
                      smallSize: 8,
                      child: Icon(_destinations[i].icon),
                    )
                  : Icon(_destinations[i].icon),
              selectedIcon: i == 1 && showPairingBadge
                  ? Badge(
                      smallSize: 8,
                      child: Icon(_destinations[i].selectedIcon),
                    )
                  : Icon(_destinations[i].selectedIcon),
              label: Text(_destinations[i].label),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 16),
            child: Text(
              'v1.0.0+1',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
      body: _pageFor(_selectedIndex),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
